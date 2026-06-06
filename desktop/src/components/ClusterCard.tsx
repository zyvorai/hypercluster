import { GlassCard } from './GlassCard'
import { StatusPill } from './StatusPill'
import { ClusterLiveStats } from './ClusterLiveStats'
import { clusterPillStatus } from '../lib/clusterStatus'
import { summarizeClusterLive } from '../lib/clusterLive'
import { revealConfig } from '../lib/api'
import type { ClusterEntry, StatusJson, VmsJson, WorkloadsJson } from '../lib/types'

export function ClusterCard({
  cluster,
  liveStatus,
  workloads,
  vms,
  liveLoading,
  runningCluster,
  onOpen,
  onConfigure,
  onDeploy,
}: {
  cluster: ClusterEntry
  liveStatus?: StatusJson | null
  workloads?: WorkloadsJson | null
  vms?: VmsJson | null
  liveLoading?: boolean
  runningCluster?: string | null
  onOpen: () => void
  onConfigure: () => void
  onDeploy: () => void
}) {
  const status = clusterPillStatus(cluster, runningCluster ?? null, liveStatus)
  const summary = summarizeClusterLive(liveStatus, workloads, vms)

  return (
    <GlassCard className="flex flex-col gap-3 shadow-zyvor-card transition hover:border-glass-accent/40 hover:shadow-zyvor-glow">
      <div className="flex items-start justify-between gap-2">
        <div className="min-w-0">
          <h3 className="text-lg font-semibold">{cluster.name}</h3>
          <p className="text-sm text-glass-muted">{cluster.distro}</p>
          <p className="truncate text-xs text-glass-muted" title={cluster.config_path}>
            {cluster.config_path}
          </p>
        </div>
        <StatusPill status={status} />
      </div>

      <ClusterLiveStats summary={summary} compact loading={liveLoading} />

      {cluster.last_action && (
        <p className="text-xs text-glass-muted">
          Last app action: {cluster.last_action}
          {cluster.last_action_ok === false ? ' (failed)' : cluster.last_action_ok ? ' (ok)' : ''}
        </p>
      )}

      <div className="mt-auto flex flex-wrap gap-2">
        <button type="button" className="btn-primary flex-1 text-sm" onClick={onOpen}>
          Open cockpit
        </button>
        <button type="button" className="btn-ghost flex-1 text-sm" onClick={onConfigure}>
          Settings
        </button>
        <button type="button" className="btn-ghost flex-1 text-sm" onClick={onDeploy}>
          Deploy
        </button>
        <button
          type="button"
          className="btn-ghost w-full text-xs"
          onClick={() => revealConfig(cluster.config_path)}
        >
          Reveal cluster.conf
        </button>
      </div>
    </GlassCard>
  )
}
