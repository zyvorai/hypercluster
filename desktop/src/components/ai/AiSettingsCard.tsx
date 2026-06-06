import { useState } from 'react'
import type { AiSettings } from '../../lib/ai/types'
import { aiAsk, mergeAiSettings, providerDefaults } from '../../lib/ai/client'
import { GlassCard } from '../GlassCard'

export function AiSettingsCard({
  settings,
  onChange,
  onSave,
}: {
  settings: AiSettings
  onChange: (s: AiSettings) => void
  onSave: () => void | Promise<void>
}) {
  const ai = mergeAiSettings(settings)
  const defaults = providerDefaults(ai.provider ?? 'openai')
  const [testing, setTesting] = useState(false)
  const [testResult, setTestResult] = useState('')

  const testConnection = async () => {
    setTesting(true)
    setTestResult('')
    try {
      await onSave()
      const reply = await aiAsk('Reply with exactly: Hypercluster AI connected.', undefined)
      setTestResult(
        reply.toLowerCase().includes('connected') ? 'Connected successfully.' : reply.slice(0, 120),
      )
    } catch (e) {
      setTestResult(String(e).slice(0, 200))
    } finally {
      setTesting(false)
    }
  }

  return (
    <GlassCard className="space-y-4 border-glass-purple/25">
      <div>
        <h2 className="text-gradient-brand text-xl font-semibold">AI Copilot</h2>
        <p className="text-sm text-glass-muted">
          Offline insights always run. Enable LLM for chat, log analysis, and natural-language
          commands (OpenAI-compatible, Anthropic, Ollama).
        </p>
      </div>

      <label className="flex items-center gap-3 text-sm">
        <input
          type="checkbox"
          checked={ai.enabled ?? false}
          onChange={(e) => onChange({ ...ai, enabled: e.target.checked })}
        />
        Enable LLM chat & analysis
      </label>

      <div className="grid gap-3 sm:grid-cols-2">
        <label className="block text-sm">
          <span className="text-glass-muted">Provider</span>
          <select
            className="input-glass mt-1 w-full"
            value={ai.provider ?? 'openai'}
            onChange={(e) => {
              const provider = e.target.value as AiSettings['provider']
              const d = providerDefaults(provider)
              onChange({
                ...ai,
                provider,
                base_url: d.base_url,
                model: d.model,
              })
            }}
          >
            <option value="openai">OpenAI / compatible</option>
            <option value="ollama">Ollama (local)</option>
            <option value="anthropic">Anthropic</option>
          </select>
        </label>
        <label className="block text-sm">
          <span className="text-glass-muted">Model</span>
          <input
            className="input-glass mt-1 w-full"
            placeholder={defaults.model}
            value={ai.model ?? ''}
            onChange={(e) => onChange({ ...ai, model: e.target.value || null })}
          />
        </label>
      </div>

      <label className="block text-sm">
        <span className="text-glass-muted">Base URL</span>
        <input
          className="input-glass mt-1 w-full"
          placeholder={defaults.base_url}
          value={ai.base_url ?? ''}
          onChange={(e) => onChange({ ...ai, base_url: e.target.value || null })}
        />
      </label>

      <label className="block text-sm">
        <span className="text-glass-muted">API key</span>
        <input
          className="input-glass mt-1 w-full"
          type="password"
          placeholder={ai.provider === 'ollama' ? 'ollama' : 'sk-… or env var'}
          value={ai.api_key ?? ''}
          onChange={(e) => onChange({ ...ai, api_key: e.target.value || null })}
          autoComplete="off"
        />
        <p className="mt-1 text-[10px] text-glass-muted">
          Or set OPENAI_API_KEY / ANTHROPIC_API_KEY in your environment.
        </p>
      </label>

      <div className="flex flex-wrap gap-2">
        <button type="button" className="btn-primary" onClick={onSave}>
          Save AI settings
        </button>
        <button
          type="button"
          className="btn-ghost"
          disabled={!ai.enabled || testing}
          onClick={() => void testConnection()}
        >
          {testing ? 'Testing…' : 'Test connection'}
        </button>
      </div>
      {testResult && (
        <p
          className={`text-sm ${testResult.includes('success') || testResult.includes('Connected') ? 'text-emerald-300' : 'text-red-300'}`}
        >
          {testResult}
        </p>
      )}

      <div className="rounded-xl border border-glass-border bg-black/20 px-3 py-2 text-xs text-glass-muted">
        <p className="font-medium text-white/80">Always available (no API key)</p>
        <ul className="mt-1 list-inside list-disc space-y-0.5">
          <li>Fleet & cluster health insights</li>
          <li>Natural-language ⌘K commands</li>
          <li>Deploy log error highlighting</li>
        </ul>
      </div>
    </GlassCard>
  )
}
