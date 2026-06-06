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

  if (health) {
    if (health.state === 'unreachable') {
      push(out, {
        severity: 'critical',
        category: 'health',
        title: 'Cluster unreachable',
        detail: health.issues[0] ?? 'Kubeconfig missing or API not responding.',
        action: { label: 'Run preflight', command: 'preflight' },
      })
    } else if (health.state === 'degraded') {
      push(out, {
        severity: 'warn',
        category: 'health',
        title: 'Cluster degraded',
        detail: health.issues.join(' · ') || 'Some nodes or pods are unhealthy.',
        action: { label: 'Full health check', command: 'test', args: [] },
      })
    } else if (health.state === 'healthy') {
      push(out, {
        severity: 'info',
        category: 'health',
        title: 'Cluster healthy',
        detail: `${health.summary.nodes_ready}/${health.summary.nodes_total} nodes, ${health.summary.pods_running} pods running.`,
      })
    }

    if (health.summary.pods_failed > 0) {
      push(out, {
        severity: 'critical',
        category: 'performance',
        title: `${health.summary.pods_failed} failed pod(s)`,
        detail: 'Check workloads view for Failed/Unknown phases. Often image pull or CNI issues.',
        action: { label: 'Ask AI to diagnose', prompt: 'Which pods are failing and why?' },
      })
    }

    if (health.summary.pods_pending > 3) {
      push(out, {
        severity: 'warn',
        category: 'performance',
        title: `${health.summary.pods_pending} pods pending`,
        detail: 'Pending pods may indicate resource pressure or scheduling issues.',
      })
    }
  }

  if (tests && tests.fail > 0) {
    const failed = tests.checks.filter((c) => !c.passed).map((c) => c.name)
    push(out, {
      severity: 'critical',
      category: 'ops',
      title: `${tests.fail} platform test(s) failed`,
      detail: failed.join(', '),
      action: { label: 'Re-run test', command: 'test' },
    })
  } else if (tests && tests.pass > 0 && tests.fail === 0) {
    push(out, {
      severity: 'info',
      category: 'ops',
      title: `Platform tests passing (${tests.pass}/${tests.pass})`,
      detail: 'Stack smoke tests all green.',
    })
  }

  if (preflight && !preflight.ok) {
    const failed = preflight.checks.filter((c) => !c.passed).map((c) => c.name)
    push(out, {
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
    if (nodeCount === 1 && spec.k8sDistro === 'k3s') {
      push(out, {
        severity: 'info',
        category: 'cost',
        title: 'Single-node lab',
        detail: 'Consider lab tune to scale down HA replicas (Cilium, cert-manager).',
        action: { label: 'lab tune', command: 'lab', args: ['tune'] },
      })
    }
    if (!spec.certManagerEnabled && spec.metallbEnabled) {
      push(out, {
        severity: 'warn',
        category: 'security',
        title: 'cert-manager disabled',
        detail: 'TLS for ingress/webhooks may fail without cert-manager on k3s platform.',
      })
    }
    if (spec.metallbEnabled && !spec.metallbIpPool?.trim()) {
      push(out, {
        severity: 'critical',
        category: 'config',
        title: 'MetalLB pool missing',
        detail: 'Set METALLB_IP_POOL in cluster.conf before deploy.',
      })
    }
    if (spec.kubevirtEnabled && !spec.longhornEnabled && nodeCount === 1) {
      push(out, {
        severity: 'info',
        category: 'config',
        title: 'KubeVirt without Longhorn',
        detail: 'Use LAB_SECONDARY_DISK or local-path for VM disks on single-node labs.',
      })
    }
  }

  if (logs?.length) {
    const errLines = logs.filter((l) => /error|failed|fatal|die:/i.test(l))
    if (errLines.length > 0) {
      push(out, {
        severity: 'warn',
        category: 'ops',
        title: `${errLines.length} error line(s) in recent logs`,
        detail: errLines.slice(-2).join(' ').slice(0, 200),
        action: { label: 'AI log analysis', prompt: 'Analyze the recent deploy logs and suggest fixes.' },
      })
    }
  }

  if (cluster?.last_action_ok === false) {
    push(out, {
      severity: 'warn',
      category: 'ops',
      title: `Last action failed: ${cluster.last_action}`,
      detail: cluster.last_action_at ?? 'Check deploy logs for details.',
      action: { label: 'Ask AI', prompt: 'Why did the last hypercluster job fail?' },
    })
  }

  return out.sort((a, b) => {
    const rank = { critical: 0, warn: 1, info: 2 }
    return rank[a.severity] - rank[b.severity]
  })
}

export function insightsSummary(insights: AiInsight[]): string {
  if (!insights.length) return 'No insights — cluster looks good or no data yet.'
  return insights
    .slice(0, 6)
    .map((i) => `[${i.severity.toUpperCase()}] ${i.title}: ${i.detail}`)
    .join('\n')
}
