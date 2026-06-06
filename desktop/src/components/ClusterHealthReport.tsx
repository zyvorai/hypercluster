import type { HealthJson, HealthState } from '../lib/types'
import { healthStateLabel } from '../lib/clusterLive'
import { ClusterLiveStats } from './ClusterLiveStats'
import { TestResultsPanel } from './TestResultsPanel'
import { GlassCard } from './GlassCard'

function stateStyles(state: HealthState): string {
  switch (state) {
    case 'healthy':
      return 'border-emerald-500/40 bg-emerald-500/10 text-emerald-200'
    case 'degraded':
      return 'border-amber-500/40 bg-amber-500/10 text-amber-200'
    case 'unreachable':
      return 'border-red-500/40 bg-red-500/10 text-red-200'
    default:
      return 'border-glass-border bg-white/5 text-glass-muted'
  }
}

export function ClusterHealthBadge({
  state,
  compact = false,
}: {
  state: HealthState
  compact?: boolean
}) {
  return (
    <span
      className={`inline-flex items-center rounded-full border px-2 py-0.5 text-[10px] font-medium uppercase tracking-wide ${stateStyles(state)} ${compact ? '' : 'text-xs'}`}
    >
      {healthStateLabel(state)}
    </span>
  )
}

export function ClusterHealthReport({
  report,
  loading = false,
  onRunFullCheck,
  fullCheckLoading = false,
}: {
  report: HealthJson | null
  loading?: boolean
  onRunFullCheck?: () => void
  fullCheckLoading?: boolean
}) {
  if (loading && !report) {
    return (
      <GlassCard>
        <p className="text-sm text-glass-muted">Connecting to cluster and loading health report…</p>
      </GlassCard>
    )
  }

  if (!report) {
    return (
      <GlassCard>
        <p className="text-sm text-glass-muted">
          Health report unavailable — verify kubeconfig in cluster.conf and SSH access.
        </p>
      </GlassCard>
    )
  }

  const summary = {
    nodesReady: report.summary.nodes_ready,
    nodesTotal: report.summary.nodes_total,
    podsRunning: report.summary.pods_running,
    podsTotal: report.summary.pods_total,
    podsPending: report.summary.pods_pending,
    podsFailed: report.summary.pods_failed,
    services: report.summary.services,
    vmsRunning: report.summary.vms_running,
    vmsTotal: report.summary.vms_total,
    reachable: report.connected && report.summary.nodes_total > 0,
  }

  return (
    <GlassCard>
      <div className="mb-4 flex flex-wrap items-center justify-between gap-2">
        <div>
          <div className="flex flex-wrap items-center gap-2">
            <h3 className="font-medium">Cluster health</h3>
            <ClusterHealthBadge state={report.state} />
          </div>
          <p className="text-xs text-glass-muted">
            Auto-connected via hypercluster health — nodes, pods, services, VMs
          </p>
        </div>
        {onRunFullCheck && (
          <button
            type="button"
            className="btn-ghost text-xs"
            disabled={fullCheckLoading}
            onClick={onRunFullCheck}
          >
            {fullCheckLoading ? 'Running platform tests…' : 'Full check (+ tests)'}
          </button>
        )}
      </div>

      {report.issues.length > 0 && (
        <ul className="mb-4 space-y-1 rounded-xl border border-amber-500/30 bg-amber-500/5 px-3 py-2 text-sm text-amber-100">
          {report.issues.map((issue) => (
            <li key={issue}>• {issue}</li>
          ))}
        </ul>
      )}

      <ClusterLiveStats summary={summary} loading={loading} />

      {report.tests && (
        <div className="mt-5 border-t border-glass-border pt-4">
          <p className="mb-2 text-xs font-medium uppercase tracking-wider text-glass-muted">
            Platform smoke ({report.tests.pass}/{report.tests.pass + report.tests.fail} pass)
          </p>
          <TestResultsPanel results={report.tests} />
        </div>
      )}

      {!report.connected && (
        <p className="mt-4 text-xs text-glass-muted">
          Kubeconfig: {report.kubeconfig || 'not configured'}
        </p>
      )}
    </GlassCard>
  )
}
