import type { AiInsight, AiInsightSeverity } from '../../lib/ai/types'

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
  onAction,
}: {
  insights: AiInsight[]
  title?: string
  compact?: boolean
  onAction?: (insight: AiInsight) => void
}) {
  if (!insights.length) {
    return (
      <div className="rounded-xl border border-glass-border bg-black/15 px-4 py-3 text-sm text-glass-muted">
        {title}: no issues detected — cluster looks good.
      </div>
    )
  }

  const shown = compact ? insights.slice(0, 3) : insights.slice(0, 8)

  return (
    <div className="space-y-2">
      <div className="flex items-center gap-2">
        <span className="text-gradient-brand text-sm font-semibold">{title}</span>
        <span className="rounded-full bg-glass-purple/20 px-2 py-0.5 text-[10px] uppercase tracking-wider text-glass-purple">
          {insights.length} insight{insights.length === 1 ? '' : 's'}
        </span>
      </div>
      <ul className="space-y-2">
        {shown.map((ins) => (
          <li
            key={ins.id}
            className={`rounded-xl border px-3 py-2 text-sm ${severityClass(ins.severity)}`}
          >
            <div className="flex items-start justify-between gap-2">
              <div>
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
          </li>
        ))}
      </ul>
      {compact && insights.length > 3 && (
        <p className="text-xs text-glass-muted">+{insights.length - 3} more in AI Copilot</p>
      )}
    </div>
  )
}
