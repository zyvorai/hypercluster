import type {
  ClusterEntry,
  ClusterSpec,
  HealthJson,
  PreflightJson,
  TestJson,
} from '../types'
import type { AiInsight } from './types'

function push(
  out: AiInsight[],
  insight: Omit<AiInsight, 'id'> & { id?: string },
) {
  out.push({ ...insight, id: insight.id ?? `${insight.category}-${out.length}` })
}

function failedPodSummary(health: HealthJson, limit = 3): string {
  const failed = (health.workloads?.pods ?? []).filter((p) =>
    ['Failed', 'Unknown', 'Error'].includes(p.phase),
  )
  if (!failed.length) return ''
  const names = failed.slice(0, limit).map((p) => `${p.namespace}/${p.name}`)
  const extra = failed.length > limit ? ` (+${failed.length - limit} more)` : ''
  return names.join(', ') + extra
}

export function generateInsights(opts: {
  cluster?: ClusterEntry | null
  health?: HealthJson | null
  tests?: TestJson | null
  preflight?: PreflightJson | null
  spec?: ClusterSpec | null
  logs?: string[]
}): AiInsight[] {
  const out: AiInsight[] = []
  const { cluster, health, tests, preflight, spec, logs } = opts
  const clusterName = cluster?.name

  const hasIssues =
    health?.state === 'degraded' ||
    health?.state === 'unreachable' ||
    (health?.summary.pods_failed ?? 0) > 0 ||
    (health?.tests?.fail ?? 0) > 0 ||
    (tests?.fail ?? 0) > 0 ||
    preflight?.ok === false

  if (health) {
    if (health.state === 'unreachable') {
      push(out, {
        clusterName,
        severity: 'critical',
        category: 'health',
        title: 'Cluster unreachable',
        detail: health.issues[0] ?? 'Kubeconfig missing or API not responding.',
        action: { label: 'Run preflight', command: 'preflight' },
      })
    } else if (health.state === 'degraded') {
      push(out, {
        clusterName,
        severity: 'warn',
        category: 'health',
        title: 'Cluster degraded',
        detail: health.issues.join(' · ') || 'Some nodes or pods are unhealthy.',
        action: { label: 'Full check', command: 'test' },
      })
    } else if (health.state === 'healthy' && !hasIssues) {
      push(out, {
        clusterName,
        severity: 'info',
        category: 'health',
        title: 'All systems go',
        detail: `${health.summary.nodes_ready}/${health.summary.nodes_total} nodes · ${health.summary.pods_running} pods · ${health.summary.services} services`,
      })
    }

    if (health.summary.pods_failed > 0) {
      const podList = failedPodSummary(health)
      push(out, {
        clusterName,
        severity: 'critical',
        category: 'performance',
        title: `${health.summary.pods_failed} failed pod(s)`,
        detail: podList
          ? `${podList} — check image pull, CNI, or resource limits.`
          : 'Check workloads for Failed/Unknown phases.',
        action: {
          label: 'Diagnose',
          prompt: `These pods are failing: ${podList || 'unknown'}. What is the likely cause and fix?`,
        },
      })
    }

    if (health.summary.pods_pending > 3) {
      push(out, {
        clusterName,
        severity: 'warn',
        category: 'performance',
        title: `${health.summary.pods_pending} pods pending`,
        detail: 'May indicate CPU/memory pressure or PVC binding delays.',
      })
    }

    if (health.tests && health.tests.fail > 0) {
      const failed = health.tests.checks.filter((c) => !c.passed).map((c) => c.name)
      push(out, {
        clusterName,
        severity: 'critical',
        category: 'ops',
        title: `${health.tests.fail} platform test(s) failed`,
        detail: failed.join(', '),
        action: { label: 'Re-run test', command: 'test' },
      })
    } else if (health.tests && health.tests.pass > 0 && health.tests.fail === 0) {
      push(out, {
        clusterName,
        severity: 'info',
        category: 'ops',
        title: `Platform tests ${health.tests.pass}/${health.tests.pass}`,
        detail: 'Stack smoke tests passing.',
      })
    }
  }

  if (tests && tests.fail > 0 && !out.some((i) => i.title.includes('platform test'))) {
    const failed = tests.checks.filter((c) => !c.passed).map((c) => c.name)
    push(out, {
      clusterName,
      severity: 'critical',
      category: 'ops',
      title: `${tests.fail} platform test(s) failed`,
      detail: failed.join(', '),
      action: { label: 'Re-run test', command: 'test' },
    })
  }

  if (preflight && !preflight.ok) {
    const failed = preflight.checks.filter((c) => !c.passed).map((c) => c.name)
    push(out, {
      clusterName,
      severity: 'warn',
      category: 'ops',
      title: 'Preflight issues',
      detail: failed.slice(0, 4).join(', '),
      action: { label: 'Run preflight', command: 'preflight' },
    })
  }

  if (spec) {
    const nodeCount =
      spec.nodes.length || spec.controlPlaneIps.length + spec.workerIps.length
    if (nodeCount === 1 && spec.k8sDistro === 'k3s' && !hasIssues) {
      push(out, {
        clusterName,
        severity: 'info',
        category: 'cost',
        title: 'Single-node lab',
        detail: 'Run lab tune to scale down HA replicas on one node.',
        action: { label: 'lab tune', command: 'lab', args: ['tune'] },
      })
    }
    if (!spec.certManagerEnabled && spec.metallbEnabled) {
      push(out, {
        clusterName,
        severity: 'warn',
        category: 'security',
        title: 'cert-manager disabled',
        detail: 'Ingress and webhook TLS may fail on k3s platform stacks.',
      })
    }
    if (spec.metallbEnabled && !spec.metallbIpPool?.trim()) {
      push(out, {
        clusterName,
        severity: 'critical',
        category: 'config',
        title: 'MetalLB pool missing',
        detail: 'Set METALLB_IP_POOL in cluster.conf before deploy.',
      })
    }
  }

  if (logs?.length) {
    const errLines = logs.filter((l) => /error|failed|fatal|die:/i.test(l))
    if (errLines.length > 0) {
      push(out, {
        clusterName,
        severity: 'warn',
        category: 'ops',
        title: `${errLines.length} error(s) in job logs`,
        detail: errLines.slice(-1)[0]?.slice(0, 160) ?? 'See deploy log console.',
        action: {
          label: 'Analyze logs',
          prompt: 'Analyze the recent hypercluster job logs and give exact next steps.',
        },
      })
    }
  }

  if (cluster?.last_action_ok === false) {
    push(out, {
      clusterName,
      severity: 'warn',
      category: 'ops',
      title: `Last job failed: ${cluster.last_action}`,
      detail: 'Review deploy logs or run preflight before retrying.',
      action: { label: 'Ask AI', prompt: 'Why did the last hypercluster job fail?' },
    })
  }

  return dedupeInsights(out).sort((a, b) => {
    const rank = { critical: 0, warn: 1, info: 2 }
    return rank[a.severity] - rank[b.severity]
  })
}

function dedupeInsights(insights: AiInsight[]): AiInsight[] {
  const seen = new Set<string>()
  return insights.filter((i) => {
    const key = `${i.category}:${i.title}:${i.detail.slice(0, 40)}`
    if (seen.has(key)) return false
    seen.add(key)
    return true
  })
}

export function insightsSummary(insights: AiInsight[]): string {
  const actionable = insights.filter((i) => i.severity !== 'info')
  const list = actionable.length ? actionable : insights
  if (!list.length) return 'No insights — cluster looks good or awaiting first health check.'
  return list
    .slice(0, 8)
    .map((i) => {
      const prefix = i.clusterName ? `[${i.clusterName}] ` : ''
      return `${prefix}[${i.severity.toUpperCase()}] ${i.title}: ${i.detail}`
    })
    .join('\n')
}

export function insightCounts(insights: AiInsight[]) {
  return {
    critical: insights.filter((i) => i.severity === 'critical').length,
    warn: insights.filter((i) => i.severity === 'warn').length,
    info: insights.filter((i) => i.severity === 'info').length,
  }
}
