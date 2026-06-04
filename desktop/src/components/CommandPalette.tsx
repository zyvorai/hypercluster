import { useEffect, useState } from 'react'
import type { ClusterEntry } from '../lib/types'

export function CommandPalette({
  open,
  onClose,
  clusters,
  onRun,
}: {
  open: boolean
  onClose: () => void
  clusters: ClusterEntry[]
  onRun: (cluster: ClusterEntry, command: string) => void
}) {
  const [q, setQ] = useState('')
  useEffect(() => {
    if (!open) setQ('')
  }, [open])

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault()
        if (open) onClose()
      }
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, onClose])

  if (!open) return null

  const cmds = ['preflight', 'deploy', 'test', 'status', 'fetch-kubeconfig']
  const filtered = clusters.filter((c) =>
    c.name.toLowerCase().includes(q.toLowerCase()),
  )

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center bg-black/60 pt-[15vh] backdrop-blur-sm">
      <div className="glass-panel-lg w-full max-w-lg overflow-hidden shadow-2xl">
        <input
          autoFocus
          className="w-full border-b border-glass-border bg-transparent px-4 py-3 outline-none"
          placeholder="Search clusters or type a command…"
          value={q}
          onChange={(e) => setQ(e.target.value)}
        />
        <div className="max-h-72 overflow-y-auto p-2">
          {filtered.length === 0 ? (
            <p className="p-3 text-sm text-glass-muted">No clusters match.</p>
          ) : (
            filtered.map((c) => (
              <div key={c.id} className="mb-2">
                <p className="px-2 py-1 text-xs font-semibold text-glass-muted">{c.name}</p>
                {cmds.map((cmd) => (
                  <button
                    key={cmd}
                    type="button"
                    className="block w-full rounded-lg px-3 py-2 text-left text-sm hover:bg-white/10"
                    onClick={() => {
                      onRun(c, cmd)
                      onClose()
                    }}
                  >
                    {cmd}
                  </button>
                ))}
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  )
}
