import { GlassCard } from './GlassCard'
import { StatusPill } from './StatusPill'
import { clusterPillStatus } from '../lib/clusterStatus'
import type { ClusterEntry } from '../lib/types'
import { revealConfig } from '../lib/api'

export function ClusterRegistryRow({
  cluster,
  runningCluster,
  selected,
  onSelect,
}: {
  cluster: ClusterEntry
  runningCluster: string | null
  selected?: boolean
  onSelect?: () => void
}) {
  const status = clusterPillStatus(cluster, runningCluster)
  return (
    <div
      className={`flex flex-wrap items-center justify-between gap-2 rounded-xl border px-3 py-2 text-sm ${
        selected ? 'border-glass-accent/50 bg-glass-accent/10' : 'border-glass-border bg-black/10'
      }`}
    >
      <button
        type="button"
        className="min-w-0 flex-1 text-left"
        onClick={onSelect}
        disabled={!onSelect}
      >
        <div className="flex items-center gap-2">
          <span className="font-medium">{cluster.name}</span>
          <StatusPill status={status} />
          <span className="text-glass-muted">{cluster.distro}</span>
        </div>
        <p className="truncate text-xs text-glass-muted">{cluster.config_path}</p>
      </button>
      <button
        type="button"
        className="btn-ghost shrink-0 text-xs"
        onClick={() => revealConfig(cluster.config_path)}
      >
        Reveal conf
      </button>
    </div>
  )
}

export function ClusterRegistryList({
  clusters,
  runningCluster,
  activeName,
  onOpen,
}: {
  clusters: ClusterEntry[]
  runningCluster: string | null
  activeName?: string
  onOpen?: (cluster: ClusterEntry) => void
}) {
  if (clusters.length === 0) {
    return <p className="text-sm text-glass-muted">No clusters registered.</p>
  }
  return (
    <GlassCard className="space-y-2">
      <h3 className="font-medium">Registered clusters</h3>
      {clusters.map((c) => (
        <ClusterRegistryRow
          key={c.id}
          cluster={c}
          runningCluster={runningCluster}
          selected={c.name === activeName}
          onSelect={onOpen ? () => onOpen(c) : undefined}
        />
      ))}
    </GlassCard>
  )
}
