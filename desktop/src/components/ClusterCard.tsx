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
  provisioned,
  runningCluster,
  onOpen,
  onConfigure,
  onDeploy,
  onDecommission,
  onReinstall,
}: {
  cluster: ClusterEntry
  liveStatus?: StatusJson | null
  workloads?: WorkloadsJson | null
  vms?: VmsJson | null
  liveLoading?: boolean
  provisioned?: boolean
  runningCluster?: string | null
  onOpen: () => void
  onConfigure: () => void
  onDeploy: () => void
  onDecommission?: () => void
  onReinstall?: () => void
}) {
  const status = clusterPillStatus(cluster, runningCluster ?? null, liveStatus)
  const summary = summarizeClusterLive(liveStatus, workloads, vms)
  const isProvisioned = provisioned ?? summary?.reachable

  return (
    <GlassCard className="flex flex-col gap-3 shadow-zyvor-card transition hover:border-glass-accent/40 hover:shadow-zyvor-glow">
      <div className="flex items-start justify-between gap-2">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <h3 className="text-lg font-semibold">{cluster.name}</h3>
            {isProvisioned ? (
              <span className="rounded-full bg-emerald-500/15 px-2 py-0.5 text-[10px] uppercase tracking-wide text-emerald-300">
                Provisioned
              </span>
            ) : null}
          </div>
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
          {isProvisioned ? 'Redeploy' : 'Deploy'}
        </button>
        {isProvisioned && onDecommission && (
          <button type="button" className="btn-ghost w-full text-xs text-red-200" onClick={onDecommission}>
            Decommission…
          </button>
        )}
        {isProvisioned && onReinstall && (
          <button type="button" className="btn-ghost w-full text-xs text-amber-200" onClick={onReinstall}>
            Reinstall (destroy + deploy)…
          </button>
        )}
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
