import { useState } from 'react'
import { insightsSummary } from '../../lib/ai/insights'
import type { AiContextBundle, AiInsight } from '../../lib/ai/types'
import { aiAsk } from '../../lib/ai/client'
import { AI_LOG_ANALYSIS_PROMPT } from '../../lib/ai/prompts'
import { GlassCard } from '../GlassCard'

export function AiLogSummary({
  logs,
  context,
  aiEnabled,
  jobSuccess,
  offlineInsights = [],
}: {
  logs: string[]
  context: AiContextBundle
  aiEnabled: boolean
  jobSuccess?: boolean | null
  offlineInsights?: AiInsight[]
}) {
  const [summary, setSummary] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const errCount = logs.filter((l) => /error|failed|fatal|die:/i.test(l)).length
  const offline = offlineInsights.length ? insightsSummary(offlineInsights) : ''

  const analyze = async () => {
    setLoading(true)
    setError('')
    try {
      const text = await aiAsk(
        'Analyze these hypercluster job logs and give a concise summary with next steps.',
        { ...context, recentLogs: logs.slice(-120).join('\n') },
        AI_LOG_ANALYSIS_PROMPT,
      )
      setSummary(text)
    } catch (e) {
      setError(String(e).slice(0, 200))
    } finally {
      setLoading(false)
    }
  }

  if (!logs.length) return null

  return (
    <GlassCard className="border-glass-purple/20">
      <div className="mb-2 flex flex-wrap items-center justify-between gap-2">
        <div>
          <h3 className="text-sm font-medium text-glass-purple">AI log analysis</h3>
          <p className="text-xs text-glass-muted">
            {errCount > 0 ? `${errCount} error line(s)` : 'No errors detected'}
            {jobSuccess === true && ' · succeeded'}
            {jobSuccess === false && ' · failed'}
          </p>
        </div>
        <button
          type="button"
          className="btn-ghost text-xs"
          disabled={!aiEnabled || loading}
          onClick={() => void analyze()}
        >
          {loading ? 'Analyzing…' : aiEnabled ? 'Deep analysis (LLM)' : 'Enable LLM in Settings'}
        </button>
      </div>
      {offline && !summary && (
        <pre className="mb-2 max-h-32 overflow-y-auto whitespace-pre-wrap rounded-xl bg-black/25 p-3 text-xs text-glass-muted">
          {offline}
        </pre>
      )}
      {summary && (
        <div className="max-h-48 overflow-y-auto whitespace-pre-wrap rounded-xl bg-black/25 p-3 text-sm leading-relaxed text-white/90">
          {summary}
        </div>
      )}
      {error && <p className="text-sm text-red-300">{error}</p>}
    </GlassCard>
  )
}
