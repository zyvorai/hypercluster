import { GlassCard } from './GlassCard'
import { StatusPill } from './StatusPill'
import type { ClusterEntry } from '../lib/types'

export function ClusterCard({
  cluster,
  nodesReady,
  nodesTotal,
  onOpen,
  onDeploy,
}: {
  cluster: ClusterEntry
  nodesReady?: number
  nodesTotal?: number
  onOpen: () => void
  onDeploy: () => void
}) {
  const status =
    cluster.last_action === 'deploy' ? 'deploying' : cluster.last_action ? 'ready' : 'unknown'
  return (
    <GlassCard className="flex flex-col gap-3 transition hover:border-glass-accent/40">
      <div className="flex items-start justify-between gap-2">
        <div>
          <h3 className="text-lg font-semibold">{cluster.name}</h3>
          <p className="text-sm text-glass-muted">{cluster.distro}</p>
        </div>
        <StatusPill status={status} />
      </div>
      {nodesTotal !== undefined && (
        <p className="text-sm text-glass-muted">
          {nodesReady ?? 0}/{nodesTotal} nodes ready
        </p>
      )}
      <div className="mt-auto flex gap-2">
        <button type="button" className="btn-ghost flex-1 text-sm" onClick={onOpen}>
          Open
        </button>
        <button type="button" className="btn-primary flex-1 text-sm" onClick={onDeploy}>
          Deploy
        </button>
      </div>
    </GlassCard>
  )
}
