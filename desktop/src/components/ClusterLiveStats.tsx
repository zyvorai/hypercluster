import type { ClusterLiveSummary } from '../lib/clusterLive'

function Stat({
  label,
  value,
  sub,
  accent,
}: {
  label: string
  value: string | number
  sub?: string
  accent?: boolean
}) {
  return (
    <div className="rounded-xl border border-glass-border bg-black/20 px-3 py-2">
      <p className="text-[10px] font-medium uppercase tracking-wider text-glass-muted">{label}</p>
      <p className={accent ? 'stat-value text-xl font-semibold' : 'text-xl font-semibold text-white'}>
        {value}
      </p>
      {sub ? <p className="text-xs text-glass-muted">{sub}</p> : null}
    </div>
  )
}

export function ClusterLiveStats({
  summary,
  compact = false,
  loading = false,
}: {
  summary: ClusterLiveSummary | null
  compact?: boolean
  loading?: boolean
}) {
  if (loading && !summary) {
    return <p className="text-sm text-glass-muted">Loading live cluster state…</p>
  }
  if (!summary) {
    return (
      <p className="text-sm text-glass-muted">
        Live state unavailable — check kubeconfig path in cluster.conf and run preflight.
      </p>
    )
  }
  if (!summary.reachable) {
    return (
      <p className="text-sm text-amber-200">
        Cluster not reachable yet — import kubeconfig or run deploy from this app.
      </p>
    )
  }

  const grid = compact ? 'grid grid-cols-2 gap-2' : 'grid grid-cols-2 gap-3 sm:grid-cols-4'

  return (
    <div className={grid}>
      <Stat
        label="Nodes"
        value={`${summary.nodesReady}/${summary.nodesTotal}`}
        sub="ready"
        accent
      />
      <Stat
        label="Pods"
        value={summary.podsRunning}
        sub={
          summary.podsTotal > summary.podsRunning
            ? `${summary.podsTotal} total · ${summary.podsPending} pending`
            : `${summary.podsTotal} total`
        }
        accent
      />
      <Stat label="Services" value={summary.services} accent={!compact} />
      <Stat
        label="VMs"
        value={summary.vmsTotal > 0 ? `${summary.vmsRunning}/${summary.vmsTotal}` : '0'}
        sub={summary.vmsTotal > 0 ? 'KubeVirt' : 'none running'}
        accent={!compact}
      />
      {summary.podsFailed > 0 && (
        <div className="col-span-full rounded-lg border border-red-500/30 bg-red-500/10 px-3 py-2 text-sm text-red-200">
          {summary.podsFailed} pod(s) failed or unknown phase
        </div>
      )}
    </div>
  )
}
