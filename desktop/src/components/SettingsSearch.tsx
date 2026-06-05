import { useMemo, useState } from 'react'
import type { ClusterSpec } from '../lib/types'
import manifest from '../lib/spec-manifest.json'

type ManifestEntry = {
  key: string
  label: string
  description: string
  group: string
  confKey?: string
  type: 'boolean' | 'string' | 'number' | 'ips'
  specPath?: string
  wired?: boolean
}

const ENTRIES = manifest as ManifestEntry[]
const WIRED = ENTRIES.filter((e) => e.wired !== false && e.specPath)
const CATALOG = ENTRIES.filter((e) => e.wired === false)

function getSpecValue(spec: ClusterSpec, path: string): unknown {
  return (spec as Record<string, unknown>)[path]
}

function setSpecValue(spec: ClusterSpec, path: string, value: unknown): ClusterSpec {
  return { ...spec, [path]: value }
}

export function SettingsSearch({
  open,
  spec,
  onChange,
  onClose,
}: {
  open: boolean
  spec: ClusterSpec
  onChange: (spec: ClusterSpec) => void
  onClose: () => void
}) {
  const [q, setQ] = useState('')

  const filtered = useMemo(() => {
    const needle = q.trim().toLowerCase()
    const pool = needle ? ENTRIES : WIRED
    if (!needle) return pool.slice(0, 40)
    return pool
      .filter(
        (e) =>
          e.label.toLowerCase().includes(needle) ||
          e.key.toLowerCase().includes(needle) ||
          e.description.toLowerCase().includes(needle) ||
          (e.confKey?.toLowerCase().includes(needle) ?? false) ||
          e.group.toLowerCase().includes(needle),
      )
      .slice(0, 50)
  }, [q])

  if (!open) return null

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center bg-black/60 pt-24 backdrop-blur-sm">
      <div className="w-full max-w-xl rounded-2xl border border-glass-border bg-[#1a1a2e] shadow-xl">
        <input
          autoFocus
          className="w-full border-b border-glass-border bg-transparent px-4 py-3 outline-none"
          placeholder="Search cluster settings…"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          onKeyDown={(e) => e.key === 'Escape' && onClose()}
        />
        <ul className="max-h-80 overflow-y-auto">
          {filtered.map((e) => {
            const path = e.specPath ?? e.key
            const val = e.specPath ? getSpecValue(spec, path) : undefined
            const editable = e.wired !== false && Boolean(e.specPath)
            return (
              <li key={e.key} className="border-b border-glass-border/30 px-4 py-2">
                <div className="flex items-start justify-between gap-2">
                  <div>
                    <p className="font-medium">
                      {e.label}
                      {!editable && (
                        <span className="ml-2 text-[10px] text-amber-200/80">Catalog</span>
                      )}
                    </p>
                    <p className="text-xs text-glass-muted">{e.description}</p>
                    {e.confKey && (
                      <p className="text-xs text-glass-accent">{e.confKey}</p>
                    )}
                  </div>
                  {editable && e.type === 'boolean' && (
                    <input
                      type="checkbox"
                      checked={Boolean(val)}
                      onChange={(ev) => onChange(setSpecValue(spec, path, ev.target.checked))}
                    />
                  )}
                  {editable && e.type === 'string' && (
                    <input
                      className="w-40 rounded border border-glass-border bg-black/20 px-2 py-1 text-xs"
                      value={String(val ?? '')}
                      onChange={(ev) => onChange(setSpecValue(spec, path, ev.target.value))}
                    />
                  )}
                  {editable && e.type === 'number' && (
                    <input
                      type="number"
                      className="w-20 rounded border border-glass-border bg-black/20 px-2 py-1 text-xs"
                      value={Number(val ?? 0)}
                      onChange={(ev) =>
                        onChange(setSpecValue(spec, path, Number(ev.target.value) || 0))
                      }
                    />
                  )}
                </div>
              </li>
            )
          })}
        </ul>
        {!q && CATALOG.length > 0 && (
          <p className="border-t border-glass-border/30 px-4 py-2 text-xs text-glass-muted">
            {CATALOG.length} catalog entries (Kyverno, Velero, …) are visible in search but not
            editable until wired to ClusterSpec.
          </p>
        )}
        <div className="px-4 py-2 text-right">
          <button type="button" className="btn-ghost text-sm" onClick={onClose}>
            Close
          </button>
        </div>
      </div>
    </div>
  )
}
