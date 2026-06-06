import type { ClusterEntry, StatusJson } from './types'

export type ClusterPillStatus = 'ready' | 'running' | 'error' | 'unknown'

export function clusterPillStatus(
  cluster: ClusterEntry,
  runningCluster: string | null,
  live?: StatusJson | null,
): ClusterPillStatus {
  if (runningCluster === cluster.name) return 'running'
  if (cluster.last_action_ok === false && !live) return 'error'
  if (live) {
    if (live.total === 0) return 'unknown'
    if (live.ready === live.total) return 'ready'
    if (live.ready > 0) return 'ready'
    return 'error'
  }
  if (cluster.last_action_ok === true) return 'ready'
  if (cluster.last_action) return 'ready'
  return 'unknown'
}
