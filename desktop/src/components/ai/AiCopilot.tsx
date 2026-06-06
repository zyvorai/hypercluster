import { useCallback, useEffect, useRef, useState } from 'react'
import type { AiContextBundle, AiInsight, AiMessage } from '../../lib/ai/types'
import { aiChat } from '../../lib/ai/client'
import { insightsSummary } from '../../lib/ai/insights'
import { QUICK_PROMPTS } from '../../lib/ai/prompts'
import { GlassCard } from '../GlassCard'
import { AiMarkdown } from './AiMarkdown'

function trimError(msg: string, max = 280): string {
  const s = msg.replace(/^Error:\s*/i, '').trim()
  return s.length > max ? `${s.slice(0, max)}…` : s
}

export function AiCopilot({
  open,
  onClose,
  context,
  initialPrompt,
  aiEnabled,
  offlineInsights = [],
  autoSendPrompt = false,
}: {
  open: boolean
  onClose: () => void
  context: AiContextBundle
  initialPrompt?: string
  aiEnabled: boolean
  offlineInsights?: AiInsight[]
  autoSendPrompt?: boolean
}) {
  const [messages, setMessages] = useState<AiMessage[]>([])
  const [input, setInput] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const bottomRef = useRef<HTMLDivElement>(null)
  const lastCluster = useRef<string | undefined>(undefined)
  const sentInitial = useRef(false)

  const send = useCallback(
    async (text: string) => {
      const q = text.trim()
      if (!q || loading) return
      if (!aiEnabled) {
        setError('Enable AI Copilot in Settings and add an API key (or use Ollama).')
        return
      }
      setError('')
      setInput('')
      setLoading(true)
      const userMsg: AiMessage = { role: 'user', content: q }
      setMessages((prev) => {
        const next = [...prev, userMsg]
        void aiChat({
          messages: next.filter((m) => m.role !== 'system'),
          context,
        })
          .then((res) => {
            setMessages((p) => [...p, { role: 'assistant', content: res.content }])
          })
          .catch((e) => {
            setError(trimError(String(e)))
          })
          .finally(() => {
            setLoading(false)
          })
        return next
      })
    },
    [aiEnabled, context, loading],
  )

  useEffect(() => {
    if (!open) {
      sentInitial.current = false
      return
    }
    if (context.clusterName !== lastCluster.current) {
      lastCluster.current = context.clusterName
      setMessages([])
      setError('')
      sentInitial.current = false
    }
    if (initialPrompt) setInput(initialPrompt)
  }, [open, context.clusterName, initialPrompt])

  useEffect(() => {
    if (!open || !autoSendPrompt || !initialPrompt || !aiEnabled || sentInitial.current) return
    sentInitial.current = true
    void send(initialPrompt)
  }, [open, autoSendPrompt, initialPrompt, aiEnabled, send])

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages, loading])

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && open) onClose()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, onClose])

  if (!open) return null

  const offlineSummary = offlineInsights.length ? insightsSummary(offlineInsights) : ''

  return (
    <div
      className="fixed inset-0 z-[60] flex justify-end bg-black/40 backdrop-blur-sm"
      onClick={onClose}
      role="presentation"
    >
      <aside
        className="glass-panel m-2 flex h-[calc(100vh-1rem)] w-full max-w-lg flex-col border-glass-purple/30 shadow-zyvor-glow"
        onClick={(e) => e.stopPropagation()}
      >
        <header className="flex items-center justify-between border-b border-glass-border px-4 py-3">
          <div>
            <h2 className="text-gradient-brand text-lg font-semibold">AI Copilot</h2>
            <p className="text-xs text-glass-muted">
              {context.clusterName ? `Context: ${context.clusterName}` : 'Fleet view — select a cluster for detail'}
              {!aiEnabled && ' · LLM off (offline insights active)'}
            </p>
          </div>
          <button type="button" className="btn-ghost text-sm" onClick={onClose}>
            Close
          </button>
        </header>

        <div className="flex gap-1 overflow-x-auto border-b border-glass-border px-3 py-2">
          {QUICK_PROMPTS.map((p) => (
            <button
              key={p.id}
              type="button"
              className="shrink-0 rounded-full bg-white/5 px-2 py-1 text-[10px] text-glass-muted hover:bg-glass-purple/20 hover:text-white"
              disabled={loading}
              onClick={() => void send(p.prompt)}
            >
              {p.icon} {p.label}
            </button>
          ))}
        </div>

        <div className="flex-1 space-y-3 overflow-y-auto px-4 py-3">
          {messages.length === 0 && offlineSummary && (
            <GlassCard className="border-glass-purple/20 text-sm">
              <p className="mb-2 text-xs font-medium uppercase tracking-wider text-glass-purple">
                Offline analysis
              </p>
              <pre className="whitespace-pre-wrap text-xs leading-relaxed text-glass-muted">
                {offlineSummary}
              </pre>
            </GlassCard>
          )}
          {messages.length === 0 && !offlineSummary && (
            <GlassCard className="text-sm text-glass-muted">
              <p className="mb-2 font-medium text-white">Zyvor AI Copilot</p>
              <p>
                Ask about health, deploy plans, logs, security, or KubeVirt. Live cluster context
                is attached automatically.
              </p>
            </GlassCard>
          )}
          {messages.map((m, i) => (
            <div
              key={i}
              className={`rounded-xl px-3 py-2 text-sm ${
                m.role === 'user'
                  ? 'ml-8 bg-glass-accent/15 text-white'
                  : 'mr-4 border border-glass-purple/20 bg-glass-purple/5 text-white/95'
              }`}
            >
              <p className="mb-1 text-[10px] uppercase tracking-wider text-glass-muted">
                {m.role === 'user' ? 'You' : 'Copilot'}
              </p>
              {m.role === 'assistant' ? (
                <AiMarkdown text={m.content} />
              ) : (
                <div className="whitespace-pre-wrap leading-relaxed">{m.content}</div>
              )}
            </div>
          ))}
          {loading && <p className="animate-pulse text-sm text-glass-muted">Thinking…</p>}
          {error && (
            <div className="rounded-xl border border-red-500/30 bg-red-500/10 px-3 py-2 text-sm text-red-200">
              {error}
            </div>
          )}
          <div ref={bottomRef} />
        </div>

        <footer className="border-t border-glass-border p-3">
          <form
            className="flex gap-2"
            onSubmit={(e) => {
              e.preventDefault()
              void send(input)
            }}
          >
            <input
              className="input-glass flex-1 text-sm"
              placeholder={
                aiEnabled ? 'Ask anything about your cluster…' : 'Enable LLM in Settings — offline insights above'
              }
              value={input}
              onChange={(e) => setInput(e.target.value)}
              disabled={loading}
            />
            <button
              type="submit"
              className="btn-primary text-sm"
              disabled={loading || !input.trim()}
            >
              Send
            </button>
          </form>
          <p className="mt-2 text-[10px] text-glass-muted">⌘J toggle · Esc close · hypercluster-only ops</p>
        </footer>
      </aside>
    </div>
  )
}
