import type { AiSettings } from '../../lib/ai/types'
import { mergeAiSettings, providerDefaults } from '../../lib/ai/client'
import { GlassCard } from '../GlassCard'

export function AiSettingsCard({
  settings,
  onChange,
  onSave,
}: {
  settings: AiSettings
  onChange: (s: AiSettings) => void
  onSave: () => void
}) {
  const ai = mergeAiSettings(settings)
  const defaults = providerDefaults(ai.provider ?? 'openai')

  return (
    <GlassCard className="space-y-4 border-glass-purple/25">
      <div>
        <h2 className="text-gradient-brand text-xl font-semibold">AI Copilot</h2>
        <p className="text-sm text-glass-muted">
          Smart insights work offline. Enable LLM for chat, log analysis, and natural-language
          commands. Supports OpenAI-compatible APIs, Anthropic, and Ollama.
        </p>
      </div>

      <label className="flex items-center gap-3 text-sm">
        <input
          type="checkbox"
          checked={ai.enabled ?? false}
          onChange={(e) => onChange({ ...ai, enabled: e.target.checked })}
        />
        Enable AI Copilot (LLM chat & analysis)
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
          placeholder={ai.provider === 'ollama' ? 'ollama (any value)' : 'sk-…'}
          value={ai.api_key ?? ''}
          onChange={(e) => onChange({ ...ai, api_key: e.target.value || null })}
          autoComplete="off"
        />
      </label>

      <div className="rounded-xl border border-glass-border bg-black/20 px-3 py-2 text-xs text-glass-muted">
        <p className="font-medium text-white/80">Offline features (no API key)</p>
        <ul className="mt-1 list-inside list-disc space-y-0.5">
          <li>Health insights & recommendations on dashboard</li>
          <li>Natural-language command hints in ⌘K palette</li>
          <li>Deploy log error detection</li>
        </ul>
      </div>

      <button type="button" className="btn-primary" onClick={onSave}>
        Save AI settings
      </button>
    </GlassCard>
  )
}
