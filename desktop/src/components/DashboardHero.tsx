import { motion } from 'framer-motion'
import type { HealthJson } from '../lib/types'
import { insightCounts } from '../lib/ai/insights'
import type { AiInsight } from '../lib/ai/types'

function FleetRing({
  healthy,
  degraded,
  unreachable,
  total,
}: {
  healthy: number
  degraded: number
  unreachable: number
  total: number
}) {
  const pct = total > 0 ? Math.round((healthy / total) * 100) : 0
  const circumference = 2 * Math.PI * 42
  const offset = circumference - (pct / 100) * circumference
  const stroke =
    unreachable > 0 ? '#f87171' : degraded > 0 ? '#fbbf24' : total > 0 ? '#34d399' : '#6b7280'

  return (
    <div className="relative flex h-28 w-28 shrink-0 items-center justify-center">
      <svg className="h-full w-full -rotate-90" viewBox="0 0 100 100">
        <circle cx="50" cy="50" r="42" fill="none" stroke="rgba(255,255,255,0.08)" strokeWidth="8" />
        <motion.circle
          cx="50"
          cy="50"
          r="42"
          fill="none"
          stroke={stroke}
          strokeWidth="8"
          strokeLinecap="round"
          strokeDasharray={circumference}
          initial={{ strokeDashoffset: circumference }}
          animate={{ strokeDashoffset: offset }}
          transition={{ duration: 0.8, ease: 'easeOut' }}
        />
      </svg>
      <div className="absolute text-center">
        <p className="stat-value text-2xl font-bold leading-none">{pct}%</p>
        <p className="text-[9px] uppercase tracking-wider text-glass-muted">healthy</p>
      </div>
    </div>
  )
}

export function DashboardHero({
  clusterCount,
  podsRunning,
  podsTotal,
  running,
  liveLoading,
  healthByCluster,
  insights,
  onRefresh,
  onOpenCopilot,
}: {
  clusterCount: number
  podsRunning: number
  podsTotal: number
  running: boolean
  liveLoading: boolean
  healthByCluster: Record<string, HealthJson | null>
  insights: AiInsight[]
  onRefresh: () => void
  onOpenCopilot: () => void
}) {
  let healthy = 0
  let degraded = 0
  let unreachable = 0
  for (const h of Object.values(healthByCluster)) {
    if (!h) continue
    if (h.state === 'healthy') healthy++
    else if (h.state === 'degraded') degraded++
    else if (h.state === 'unreachable') unreachable++
  }
  const total = healthy + degraded + unreachable
  const counts = insightCounts(insights)

  return (
    <motion.div
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      className="hero-panel mb-6 flex flex-wrap items-center gap-6 p-6"
    >
      <FleetRing healthy={healthy} degraded={degraded} unreachable={unreachable} total={total} />
      <div className="min-w-0 flex-1">
        <p className="mb-1 text-xs font-medium uppercase tracking-[0.25em] text-glass-accent-light">
          Fleet command
        </p>
        <h2 className="text-gradient-brand text-3xl font-bold tracking-tight">Your clusters</h2>
        <p className="mt-2 max-w-xl text-sm text-glass-muted">
          {clusterCount === 0
            ? 'Import or create a cluster to start deploying k3s platform stacks.'
            : liveLoading
              ? 'Syncing live health from hypercluster…'
              : `${clusterCount} registered · ${podsRunning} pods running · ${counts.critical + counts.warn} open insight${counts.critical + counts.warn === 1 ? '' : 's'}`}
        </p>
        <div className="mt-4 flex flex-wrap gap-2">
          <button
            type="button"
            className="btn-primary text-sm"
            disabled={liveLoading || clusterCount === 0}
            onClick={onRefresh}
          >
            {liveLoading ? (
              <span className="inline-flex items-center gap-2">
                <span className="spinner" /> Refreshing…
              </span>
            ) : (
              'Refresh health'
            )}
          </button>
          <button type="button" className="btn-ghost text-sm" onClick={onOpenCopilot}>
            AI Copilot ⌘J
          </button>
          {running && (
            <span className="inline-flex items-center gap-2 rounded-full border border-amber-500/30 bg-amber-500/10 px-3 py-1.5 text-xs text-amber-200">
              <span className="pulse-dot pulse-dot-amber" />
              Job running
            </span>
          )}
        </div>
      </div>
      <div className="grid grid-cols-3 gap-3 sm:gap-4">
        {[
          { label: 'Clusters', value: clusterCount },
          { label: 'Pods', value: `${podsRunning}/${podsTotal}` },
          { label: 'Issues', value: counts.critical + counts.warn, warn: counts.critical > 0 },
        ].map((s, i) => (
          <motion.div
            key={s.label}
            initial={{ opacity: 0, scale: 0.92 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ delay: 0.05 * i }}
            className="hero-stat-tile"
          >
            <p className="text-[10px] uppercase tracking-wider text-glass-muted">{s.label}</p>
            <p className={`text-2xl font-semibold ${s.warn ? 'text-red-300' : 'stat-value'}`}>{s.value}</p>
          </motion.div>
        ))}
      </div>
    </motion.div>
  )
}
