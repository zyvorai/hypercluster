import { GlassCard } from './GlassCard'
import { StatusPill } from './StatusPill'
import { clusterPillStatus } from '../lib/clusterStatus'
import { revealConfig } from '../lib/api'
import type { ClusterEntry } from '../lib/types'

export function ClusterCard({
  cluster,
  nodesReady,
  nodesTotal,
  runningCluster,
  onOpen,
  onConfigure,
  onDeploy,
}: {
  cluster: ClusterEntry
  nodesReady?: number
  nodesTotal?: number
  runningCluster?: string | null
  onOpen: () => void
  onConfigure: () => void
  onDeploy: () => void
}) {
  const status = clusterPillStatus(cluster, runningCluster ?? null)
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
      {nodesTotal !== undefined && (
        <p className="text-sm text-glass-muted">
          {nodesReady ?? 0}/{nodesTotal} nodes ready
        </p>
      )}
      {cluster.last_action && (
        <p className="text-xs text-glass-muted">
          Last: {cluster.last_action}
          {cluster.last_action_ok === false ? ' (failed)' : cluster.last_action_ok ? ' (ok)' : ''}
        </p>
      )}
      <div className="mt-auto flex flex-wrap gap-2">
        <button type="button" className="btn-ghost flex-1 text-sm" onClick={onOpen}>
          Open
        </button>
        <button type="button" className="btn-ghost flex-1 text-sm" onClick={onConfigure}>
          Settings
        </button>
        <button type="button" className="btn-primary flex-1 text-sm" onClick={onDeploy}>
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
