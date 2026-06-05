import type { ClusterEntry } from './types'

export type ClusterPillStatus = 'ready' | 'running' | 'error' | 'unknown'

export function clusterPillStatus(
  cluster: ClusterEntry,
  runningCluster: string | null,
): ClusterPillStatus {
  if (runningCluster === cluster.name) return 'running'
  if (cluster.last_action_ok === false) return 'error'
  if (cluster.last_action) return 'ready'
  return 'unknown'
}
