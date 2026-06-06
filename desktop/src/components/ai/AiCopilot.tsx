import { useEffect, useRef, useState } from 'react'
import type { AiContextBundle, AiMessage } from '../../lib/ai/types'
import { aiChat } from '../../lib/ai/client'
import { QUICK_PROMPTS } from '../../lib/ai/prompts'
import { GlassCard } from '../GlassCard'

export function AiCopilot({
  open,
  onClose,
  context,
  initialPrompt,
  aiEnabled,
}: {
  open: boolean
  onClose: () => void
  context: AiContextBundle
  initialPrompt?: string
  aiEnabled: boolean
}) {
  const [messages, setMessages] = useState<AiMessage[]>([])
  const [input, setInput] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const bottomRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!open) return
    if (initialPrompt) {
      setInput(initialPrompt)
    }
  }, [open, initialPrompt])

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

  const send = async (text: string) => {
    const q = text.trim()
    if (!q || loading) return
    setError('')
    const userMsg: AiMessage = { role: 'user', content: q }
    const next = [...messages, userMsg]
    setMessages(next)
    setInput('')
    setLoading(true)
    try {
      const res = await aiChat({
        messages: next.filter((m) => m.role !== 'system'),
        context,
      })
      setMessages([...next, { role: 'assistant', content: res.content }])
    } catch (e) {
      setError(String(e))
    } finally {
      setLoading(false)
    }
  }

  if (!open) return null

  return (
    <div className="fixed inset-0 z-[60] flex justify-end bg-black/40 backdrop-blur-sm">
      <aside className="glass-panel m-2 flex h-[calc(100vh-1rem)] w-full max-w-lg flex-col border-glass-purple/30 shadow-zyvor-glow">
        <header className="flex items-center justify-between border-b border-glass-border px-4 py-3">
          <div>
            <h2 className="text-gradient-brand text-lg font-semibold">AI Copilot</h2>
            <p className="text-xs text-glass-muted">
              {context.clusterName ? `Context: ${context.clusterName}` : 'No cluster selected'}
              {!aiEnabled && ' · Enable AI in Settings'}
            </p>
          </div>
          <button type="button" className="btn-ghost text-sm" onClick={onClose}>
            Close
          </button>
        </header>

        <div className="flex flex-wrap gap-1 border-b border-glass-border px-3 py-2">
          {QUICK_PROMPTS.slice(0, 6).map((p) => (
            <button
              key={p.id}
              type="button"
              className="rounded-full bg-white/5 px-2 py-1 text-[10px] text-glass-muted hover:bg-glass-purple/20 hover:text-white"
              disabled={loading}
              onClick={() => void send(p.prompt)}
            >
              {p.icon} {p.label}
            </button>
          ))}
        </div>

        <div className="flex-1 space-y-3 overflow-y-auto px-4 py-3">
          {messages.length === 0 && (
            <GlassCard className="text-sm text-glass-muted">
              <p className="mb-2 font-medium text-white">Zyvor AI Copilot</p>
              <p>
                Ask about health, deploy plans, log analysis, security, KubeVirt VMs, or
                troubleshooting. Uses live cluster context when available.
              </p>
              {!aiEnabled && (
                <p className="mt-2 text-amber-200">
                  Enable AI in Settings and add an API key (or use local Ollama).
                </p>
              )}
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
              <div className="whitespace-pre-wrap leading-relaxed">{m.content}</div>
            </div>
          ))}
          {loading && (
            <p className="text-sm text-glass-muted animate-pulse">Thinking…</p>
          )}
          {error && <p className="text-sm text-red-300">{error}</p>}
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
              placeholder={aiEnabled ? 'Ask anything about your cluster…' : 'Enable AI in Settings first'}
              value={input}
              onChange={(e) => setInput(e.target.value)}
              disabled={loading}
            />
            <button type="submit" className="btn-primary text-sm" disabled={loading || !input.trim()}>
              Send
            </button>
          </form>
          <p className="mt-2 text-[10px] text-glass-muted">⌘J toggle · Esc close</p>
        </footer>
      </aside>
    </div>
  )
}
