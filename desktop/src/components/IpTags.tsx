import { useState } from 'react'

export function IpTags({
  label,
  ips,
  onChange,
  hint,
}: {
  label: string
  ips: string[]
  onChange: (ips: string[]) => void
  hint?: string
}) {
  const [draft, setDraft] = useState('')
  return (
    <div>
      <label className="mb-1 block text-sm text-glass-muted">{label}</label>
      {hint && <p className="mb-1 text-xs text-glass-muted">{hint}</p>}
      <div className="flex flex-wrap gap-2 rounded-xl border border-glass-border bg-black/20 p-2">
        {ips.map((ip) => (
          <span
            key={ip}
            className="flex items-center gap-1 rounded-full bg-glass-accent/20 px-3 py-1 text-sm"
          >
            {ip}
            <button
              type="button"
              className="text-glass-muted hover:text-white"
              onClick={() => onChange(ips.filter((x) => x !== ip))}
            >
              ×
            </button>
          </span>
        ))}
        <input
          className="min-w-[140px] flex-1 bg-transparent text-sm outline-none"
          placeholder="IP address, Enter"
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && draft.trim()) {
              onChange([...ips, draft.trim()])
              setDraft('')
            }
          }}
        />
      </div>
    </div>
  )
}
