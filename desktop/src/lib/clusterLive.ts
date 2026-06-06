import type { StatusJson, VmsJson, WorkloadsJson, HealthJson, HealthState } from './types'

export type ClusterLiveSummary = {
  nodesReady: number
  nodesTotal: number
  podsRunning: number
  podsTotal: number
  podsPending: number
  podsFailed: number
  services: number
  vmsRunning: number
  vmsTotal: number
  reachable: boolean
}

export function summarizeClusterLive(
  status: StatusJson | null | undefined,
  workloads: WorkloadsJson | null | undefined,
  vms: VmsJson | null | undefined,
): ClusterLiveSummary | null {
  if (!status && !workloads && !vms) return null
  const pods = workloads?.pods ?? []
  const running = pods.filter((p) => p.phase === 'Running').length
  const pending = pods.filter((p) => p.phase === 'Pending').length
  const failed = pods.filter(
    (p) => p.phase === 'Failed' || p.phase === 'Unknown' || p.phase === 'Error',
  ).length
  const vmList = vms?.vms ?? []
  const vmsRunning = vmList.filter((v) => v.phase === 'Running').length
  return {
    nodesReady: status?.ready ?? 0,
    nodesTotal: status?.total ?? 0,
    podsRunning: running,
    podsTotal: pods.length,
    podsPending: pending,
    podsFailed: failed,
    services: workloads?.services?.length ?? 0,
    vmsRunning,
    vmsTotal: vmList.length,
    reachable: Boolean(status && status.total > 0),
  }
}

export function healthStateLabel(state: HealthState): string {
  switch (state) {
    case 'healthy':
      return 'Healthy'
    case 'degraded':
      return 'Degraded'
    case 'unreachable':
      return 'Unreachable'
    default:
      return 'Unknown'
  }
}

export function healthFromReport(report: HealthJson): ClusterLiveSummary {
  const s = report.summary
  return {
    nodesReady: s.nodes_ready,
    nodesTotal: s.nodes_total,
    podsRunning: s.pods_running,
    podsTotal: s.pods_total,
    podsPending: s.pods_pending,
    podsFailed: s.pods_failed,
    services: s.services,
    vmsRunning: s.vms_running,
    vmsTotal: s.vms_total,
    reachable: report.connected && s.nodes_total > 0,
  }
}
