import { useMemo, useState } from 'react'
import { motion } from 'framer-motion'
import type { AiInsight, AiInsightSeverity } from '../../lib/ai/types'
import { insightCounts } from '../../lib/ai/insights'

function severityClass(s: AiInsightSeverity): string {
  switch (s) {
    case 'critical':
      return 'border-red-500/40 bg-red-500/10 text-red-100'
    case 'warn':
      return 'border-amber-500/40 bg-amber-500/10 text-amber-100'
    default:
      return 'border-glass-purple/30 bg-glass-purple/5 text-white/90'
  }
}

function severityLabel(s: AiInsightSeverity): string {
  switch (s) {
    case 'critical':
      return 'Critical'
    case 'warn':
      return 'Warning'
    default:
      return 'Info'
  }
}

function categoryIcon(cat: AiInsight['category']): string {
  switch (cat) {
    case 'health':
      return '◆'
    case 'security':
      return '🔒'
    case 'ops':
      return '⚡'
    case 'performance':
      return '▲'
    case 'cost':
      return '◎'
    default:
      return '◇'
  }
}

export function AiInsightPanel({
  insights,
  title = 'AI insights',
  compact = false,
  showCluster = false,
  onAction,
  onOpenCopilot,
}: {
  insights: AiInsight[]
  title?: string
  compact?: boolean
  showCluster?: boolean
  onAction?: (insight: AiInsight) => void
  onOpenCopilot?: () => void
}) {
  const [issuesOnly, setIssuesOnly] = useState(true)
  const counts = useMemo(() => insightCounts(insights), [insights])

  const filtered = useMemo(() => {
    if (!issuesOnly) return insights
    return insights.filter((i) => i.severity !== 'info')
  }, [insights, issuesOnly])

  const shown = compact ? filtered.slice(0, 3) : filtered.slice(0, 10)

  if (!insights.length) {
    return (
      <div className="rounded-xl border border-glass-border bg-black/15 px-4 py-3 text-sm text-glass-muted">
        {title}: waiting for health data — import cluster or refresh health.
      </div>
    )
  }

  if (!filtered.length && issuesOnly) {
    return (
      <div className="space-y-2">
        <Header
          title={title}
          counts={counts}
          issuesOnly={issuesOnly}
          onToggle={() => setIssuesOnly(false)}
          onOpenCopilot={onOpenCopilot}
        />
        <div className="rounded-xl border border-emerald-500/30 bg-emerald-500/10 px-4 py-3 text-sm text-emerald-100">
          No open issues — {counts.info} informational tip{counts.info === 1 ? '' : 's'} available.
          <button
            type="button"
            className="ml-2 text-xs underline"
            onClick={() => setIssuesOnly(false)}
          >
            Show all
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-2">
      <Header
        title={title}
        counts={counts}
        issuesOnly={issuesOnly}
        onToggle={() => setIssuesOnly((v) => !v)}
        onOpenCopilot={onOpenCopilot}
      />
      <ul className="space-y-2">
        {shown.map((ins, i) => (
          <motion.li
            key={ins.id}
            initial={{ opacity: 0, x: -6 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: i * 0.04 }}
            className={`insight-card rounded-xl border px-3 py-2 text-sm ${severityClass(ins.severity)}`}
          >
            <div className="flex items-start justify-between gap-2">
              <div className="min-w-0">
                <div className="mb-1 flex flex-wrap items-center gap-2">
                  <span className="rounded bg-black/20 px-1.5 py-0.5 text-[9px] uppercase tracking-wider">
                    {severityLabel(ins.severity)}
                  </span>
                  {showCluster && ins.clusterName && (
                    <span className="text-[10px] text-glass-muted">{ins.clusterName}</span>
                  )}
                </div>
                <p className="font-medium">
                  {categoryIcon(ins.category)} {ins.title}
                </p>
                <p className="mt-0.5 text-xs opacity-90">{ins.detail}</p>
              </div>
              {ins.action && onAction && (
                <button
                  type="button"
                  className="shrink-0 rounded-lg bg-white/10 px-2 py-1 text-[10px] uppercase tracking-wide hover:bg-white/15"
                  onClick={() => onAction(ins)}
                >
                  {ins.action.label}
                </button>
              )}
            </div>
          </motion.li>
        ))}
      </ul>
      {compact && filtered.length > 3 && (
        <p className="text-xs text-glass-muted">+{filtered.length - 3} more — open AI Copilot ⌘J</p>
      )}
    </div>
  )
}

function Header({
  title,
  counts,
  issuesOnly,
  onToggle,
  onOpenCopilot,
}: {
  title: string
  counts: ReturnType<typeof insightCounts>
  issuesOnly: boolean
  onToggle: () => void
  onOpenCopilot?: () => void
}) {
  return (
    <div className="flex flex-wrap items-center justify-between gap-2">
      <div className="flex flex-wrap items-center gap-2">
        <span className="text-gradient-brand text-sm font-semibold">{title}</span>
        {counts.critical > 0 && (
          <span className="rounded-full bg-red-500/20 px-2 py-0.5 text-[10px] text-red-200">
            {counts.critical} critical
          </span>
        )}
        {counts.warn > 0 && (
          <span className="rounded-full bg-amber-500/20 px-2 py-0.5 text-[10px] text-amber-200">
            {counts.warn} warn
          </span>
        )}
      </div>
      <div className="flex gap-2">
        <button type="button" className="btn-ghost text-[10px]" onClick={onToggle}>
          {issuesOnly ? 'Show tips' : 'Issues only'}
        </button>
        {onOpenCopilot && (
          <button type="button" className="btn-ghost text-[10px]" onClick={onOpenCopilot}>
            Copilot ⌘J
          </button>
        )}
      </div>
    </div>
  )
}
