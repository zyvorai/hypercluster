import { motion } from 'framer-motion'
import { GlassCard } from './GlassCard'
import { StatusPill } from './StatusPill'
import { ClusterLiveStats } from './ClusterLiveStats'
import { ClusterHealthBadge } from './ClusterHealthReport'
import { clusterPillStatus } from '../lib/clusterStatus'
import { summarizeClusterLive } from '../lib/clusterLive'
import { revealConfig } from '../lib/api'
import type { ClusterEntry, HealthJson, HealthState, StatusJson, VmsJson, WorkloadsJson } from '../lib/types'

function healthCardClass(state?: HealthState): string {
  if (state === 'healthy') return 'cluster-card--healthy'
  if (state === 'degraded') return 'cluster-card--degraded'
  if (state === 'unreachable') return 'cluster-card--unreachable'
  return ''
}

export function ClusterCard({
  cluster,
  liveStatus,
  health,
  workloads,
  vms,
  liveLoading,
  provisioned,
  runningCluster,
  index = 0,
  onOpen,
  onConfigure,
  onDeploy,
  onDecommission,
  onReinstall,
}: {
  cluster: ClusterEntry
  liveStatus?: StatusJson | null
  health?: HealthJson | null
  workloads?: WorkloadsJson | null
  vms?: VmsJson | null
  liveLoading?: boolean
  provisioned?: boolean
  runningCluster?: string | null
  index?: number
  onOpen: () => void
  onConfigure: () => void
  onDeploy: () => void
  onDecommission?: () => void
  onReinstall?: () => void
}) {
  const status = clusterPillStatus(cluster, runningCluster ?? null, liveStatus)
  const summary = summarizeClusterLive(liveStatus, workloads, vms)
  const isProvisioned = provisioned ?? summary?.reachable
  const healthState = health?.state
  const isRunning = runningCluster === cluster.name

  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: index * 0.05, duration: 0.3, ease: [0.22, 1, 0.36, 1] }}
    >
      <GlassCard
        interactive
        className={`cluster-card flex flex-col gap-3 shadow-zyvor-card ${healthCardClass(healthState)} ${isRunning ? 'cluster-card--running' : ''}`}
      >
        <div className="flex items-start justify-between gap-2">
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-2">
              <h3 className="text-lg font-semibold">{cluster.name}</h3>
              {isProvisioned ? (
                <span className="inline-flex items-center gap-1.5 rounded-full bg-emerald-500/15 px-2 py-0.5 text-[10px] uppercase tracking-wide text-emerald-300">
                  <span className="pulse-dot pulse-dot-emerald" />
                  Live
                </span>
              ) : null}
              {healthState ? <ClusterHealthBadge state={healthState} compact /> : null}
            </div>
            <p className="text-sm capitalize text-glass-muted">{cluster.distro}</p>
            <p className="truncate text-xs text-glass-muted" title={cluster.config_path}>
              {cluster.config_path}
            </p>
          </div>
          <StatusPill status={status} />
        </div>

        {liveLoading && !summary ? (
          <div className="space-y-2">
            <div className="skeleton h-12 w-full" />
            <div className="skeleton h-12 w-full" />
          </div>
        ) : (
          <ClusterLiveStats summary={summary} compact loading={liveLoading} />
        )}

        {health?.tests && (
          <p className="text-xs text-glass-muted">
            Platform tests:{' '}
            <span className={health.tests.fail > 0 ? 'text-amber-200' : 'text-emerald-300'}>
              {health.tests.pass}/{health.tests.pass + health.tests.fail} pass
            </span>
          </p>
        )}

        {health?.issues && health.issues.length > 0 && (
          <p className="rounded-lg border border-amber-500/25 bg-amber-500/8 px-2.5 py-1.5 text-xs text-amber-200">
            {health.issues[0]}
          </p>
        )}

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
    </motion.div>
  )
}
