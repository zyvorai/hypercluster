import type {
  ClusterEntry,
  ClusterSpec,
  HealthJson,
  PreflightJson,
  TestJson,
} from '../types'
import type { AiContextBundle } from './types'

export function summarizeSpec(spec: ClusterSpec): string {
  const nodes = spec.nodes.length
    ? spec.nodes.map((n) => `${n.hostname} (${n.ip}) [${n.roles.join(',')}]`).join('; ')
    : [...spec.controlPlaneIps, ...spec.workerIps].join(', ')
  return [
    `Cluster: ${spec.clusterName}`,
    `Distro: ${spec.k8sDistro}`,
    `K8s: ${spec.kubeVersion}`,
    `CNI: ${spec.cniPlugin}`,
    `Nodes: ${nodes || 'none configured'}`,
    `MetalLB: ${spec.metallbEnabled ? spec.metallbIpPool || 'on' : 'off'}`,
    `KubeVirt: ${spec.kubevirtEnabled ? 'on' : 'off'}`,
    `Longhorn: ${spec.longhornEnabled ? 'on' : 'off'}`,
    `cert-manager: ${spec.certManagerEnabled ? 'on' : 'off'}`,
    `metrics-server: ${spec.metricsServerEnabled ? 'on' : 'off'}`,
    `GPU operator: ${spec.gpuOperatorEnabled ? 'on' : 'off'}`,
  ].join('\n')
}

export function summarizeHealth(health: HealthJson | null | undefined): string {
  if (!health) return 'No health data.'
  const s = health.summary
  const lines = [
    `State: ${health.state}`,
    `Connected: ${health.connected}`,
    `Nodes: ${s.nodes_ready}/${s.nodes_total} ready`,
    `Pods: ${s.pods_running} running / ${s.pods_total} total (${s.pods_pending} pending, ${s.pods_failed} failed)`,
    `Services: ${s.services}`,
    `VMs: ${s.vms_running}/${s.vms_total}`,
  ]
  if (health.issues.length) lines.push(`Issues: ${health.issues.join('; ')}`)
  if (health.tests) {
    lines.push(`Platform tests: ${health.tests.pass} pass, ${health.tests.fail} fail`)
    const failed = health.tests.checks.filter((c) => !c.passed).map((c) => c.name)
    if (failed.length) lines.push(`Failed checks: ${failed.join(', ')}`)
  }
  return lines.join('\n')
}

export function summarizeTests(tests: TestJson | null | undefined): string {
  if (!tests) return ''
  const failed = tests.checks.filter((c) => !c.passed)
  return [
    `Tests: ${tests.pass} pass, ${tests.fail} fail`,
    ...failed.map((c) => `- FAIL: ${c.name}`),
    ...tests.checks.filter((c) => c.passed).slice(0, 5).map((c) => `- PASS: ${c.name}`),
  ].join('\n')
}

export function summarizePreflight(pf: PreflightJson | null | undefined): string {
  if (!pf) return ''
  const failed = pf.checks.filter((c) => !c.passed)
  return [
    `Preflight ok: ${pf.ok}`,
    ...failed.map((c) => `- FAIL: ${c.name}${c.detail ? ` (${c.detail})` : ''}`),
  ].join('\n')
}

export function summarizeLogs(logs: string[], maxLines = 80): string {
  const tail = logs.slice(-maxLines)
  if (!tail.length) return 'No recent logs.'
  return tail.join('\n')
}

export function buildAiContext(opts: {
  cluster?: ClusterEntry | null
  health?: HealthJson | null
  tests?: TestJson | null
  preflight?: PreflightJson | null
  logs?: string[]
  spec?: ClusterSpec | null
}): AiContextBundle {
  return {
    clusterName: opts.cluster?.name,
    distro: opts.cluster?.distro,
    configPath: opts.cluster?.config_path,
    healthJson: opts.health ? summarizeHealth(opts.health) : undefined,
    testJson: opts.tests ? summarizeTests(opts.tests) : undefined,
    preflightJson: opts.preflight ? summarizePreflight(opts.preflight) : undefined,
    recentLogs: opts.logs?.length ? summarizeLogs(opts.logs) : undefined,
    specSummary: opts.spec ? summarizeSpec(opts.spec) : undefined,
  }
}

export function contextToPromptBlock(ctx: AiContextBundle): string {
  const parts: string[] = []
  if (ctx.clusterName) parts.push(`# Cluster: ${ctx.clusterName} (${ctx.distro ?? 'unknown'})`)
  if (ctx.configPath) parts.push(`Config: ${ctx.configPath}`)
  if (ctx.specSummary) parts.push(`\n## Spec\n${ctx.specSummary}`)
  if (ctx.healthJson) parts.push(`\n## Health\n${ctx.healthJson}`)
  if (ctx.testJson) parts.push(`\n## Tests\n${ctx.testJson}`)
  if (ctx.preflightJson) parts.push(`\n## Preflight\n${ctx.preflightJson}`)
  if (ctx.recentLogs) parts.push(`\n## Recent logs\n${ctx.recentLogs}`)
  return parts.join('\n')
}
