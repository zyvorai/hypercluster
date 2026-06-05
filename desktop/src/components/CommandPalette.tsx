import { useEffect, useMemo, useState } from 'react'
import type { ClusterEntry } from '../lib/types'

const RUN_COMMANDS = [
  { id: 'preflight', label: 'preflight' },
  { id: 'deploy', label: 'deploy' },
  { id: 'test', label: 'test' },
  { id: 'test --full', label: 'test --full', command: 'test', args: ['--full'] },
  { id: 'status', label: 'status' },
  { id: 'fetch-kubeconfig', label: 'fetch-kubeconfig' },
  { id: 'merge-kubeconfig', label: 'merge-kubeconfig' },
  { id: 'unlock', label: 'unlock' },
]

const NAV_ACTIONS = [
  { id: 'open-detail', label: 'Open cluster detail' },
  { id: 'edit-settings', label: 'Edit cluster settings (IPs, SSH, …)' },
  { id: 'edit-conf', label: 'Edit raw cluster.conf' },
]

const APP_ACTIONS = [
  { id: 'create-hub', label: 'Create cluster (Studio hub)' },
  { id: 'quick-virt', label: 'Quick Deploy — Virtualization' },
  { id: 'quick-gpu', label: 'Quick Deploy — AI / GPU' },
  { id: 'import-conf', label: 'Import cluster.conf' },
]

export type PaletteSelection =
  | { kind: 'run'; cluster: ClusterEntry; command: string; args?: string[] }
  | { kind: 'detail'; cluster: ClusterEntry }
  | { kind: 'settings'; cluster: ClusterEntry }
  | { kind: 'edit'; cluster: ClusterEntry }
  | { kind: 'app'; action: string }

export function CommandPalette({
  open,
  onClose,
  clusters,
  onSelect,
}: {
  open: boolean
  onClose: () => void
  clusters: ClusterEntry[]
  onSelect: (selection: PaletteSelection) => void
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

  const needle = q.trim().toLowerCase()
  const filteredClusters = useMemo(
    () =>
      clusters.filter(
        (c) =>
          !needle ||
          c.name.toLowerCase().includes(needle) ||
          c.distro.toLowerCase().includes(needle) ||
          c.config_path.toLowerCase().includes(needle),
      ),
    [clusters, needle],
  )

  const filteredNav = useMemo(
    () => NAV_ACTIONS.filter((a) => !needle || a.label.toLowerCase().includes(needle)),
    [needle],
  )

  const filteredCommands = useMemo(
    () => RUN_COMMANDS.filter((cmd) => !needle || cmd.label.toLowerCase().includes(needle)),
    [needle],
  )

  const filteredApp = useMemo(
    () => APP_ACTIONS.filter((a) => !needle || a.label.toLowerCase().includes(needle)),
    [needle],
  )

  if (!open) return null

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center bg-black/60 pt-[15vh] backdrop-blur-sm">
      <div className="glass-panel-lg w-full max-w-lg overflow-hidden shadow-2xl">
        <input
          autoFocus
          className="w-full border-b border-glass-border bg-transparent px-4 py-3 outline-none"
          placeholder="Search clusters, commands, or actions…"
          value={q}
          onChange={(e) => setQ(e.target.value)}
        />
        <div className="max-h-80 overflow-y-auto p-2">
          {filteredApp.length > 0 && (
            <div className="mb-3">
              <p className="px-2 py-1 text-xs font-semibold text-glass-muted">App</p>
              {filteredApp.map((action) => (
                <button
                  key={action.id}
                  type="button"
                  className="block w-full rounded-lg px-3 py-2 text-left text-sm hover:bg-white/10"
                  onClick={() => {
                    onSelect({ kind: 'app', action: action.id })
                    onClose()
                  }}
                >
                  {action.label}
                </button>
              ))}
            </div>
          )}
          {filteredClusters.length === 0 && filteredApp.length === 0 ? (
            <p className="p-3 text-sm text-glass-muted">No matches.</p>
          ) : (
            filteredClusters.map((c) => (
              <div key={c.id} className="mb-2">
                <p className="px-2 py-1 text-xs font-semibold text-glass-muted">{c.name}</p>
                {filteredNav.map((action) => (
                  <button
                    key={`${c.id}-${action.id}`}
                    type="button"
                    className="block w-full rounded-lg px-3 py-2 text-left text-sm hover:bg-white/10"
                    onClick={() => {
                      if (action.id === 'open-detail') {
                        onSelect({ kind: 'detail', cluster: c })
                      } else if (action.id === 'edit-settings') {
                        onSelect({ kind: 'settings', cluster: c })
                      } else {
                        onSelect({ kind: 'edit', cluster: c })
                      }
                      onClose()
                    }}
                  >
                    {action.label}
                  </button>
                ))}
                {filteredCommands.map((cmd) => (
                  <button
                    key={`${c.id}-${cmd.id}`}
                    type="button"
                    className="block w-full rounded-lg px-3 py-2 text-left text-sm hover:bg-white/10"
                    onClick={() => {
                      onSelect({
                        kind: 'run',
                        cluster: c,
                        command: cmd.command ?? cmd.id,
                        args: cmd.args,
                      })
                      onClose()
                    }}
                  >
                    {cmd.label}
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
