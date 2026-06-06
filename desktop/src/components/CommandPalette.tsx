import { useEffect, useMemo, useState } from 'react'
import type { ClusterEntry } from '../lib/types'
import { parseNaturalLanguage, nlCommandHint } from '../lib/ai/nlCommand'

const RUN_COMMANDS = [
  { id: 'preflight', label: 'preflight' },
  { id: 'deploy-full', label: 'deploy full (preflight → deploy → test)', command: 'deploy-full' },
  { id: 'decommission', label: 'decommission (destroy cluster)', command: 'decommission' },
  { id: 'reinstall', label: 'reinstall (destroy → deploy → test)', command: 'reinstall' },
  { id: 'deploy', label: 'deploy' },
  { id: 'test', label: 'test' },
  { id: 'test --full', label: 'test --full', command: 'test', args: ['--full'] },
  { id: 'lab setup', label: 'lab setup', command: 'lab', args: ['setup'] },
  { id: 'lab tune', label: 'lab tune', command: 'lab', args: ['tune'] },
  { id: 'lab storage', label: 'lab storage --status', command: 'lab', args: ['storage', '--status'] },
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
  { id: 'scan-clusters', label: 'Scan for cluster.conf files' },
  { id: 'open-ai', label: 'Open AI Copilot' },
]

export type PaletteSelection =
  | { kind: 'run'; cluster: ClusterEntry; command: string; args?: string[] }
  | { kind: 'detail'; cluster: ClusterEntry }
  | { kind: 'settings'; cluster: ClusterEntry }
  | { kind: 'edit'; cluster: ClusterEntry }
  | { kind: 'app'; action: string }
  | { kind: 'ai'; query: string; cluster?: ClusterEntry }

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

  const nlParsed = useMemo(
    () => (needle.length >= 2 ? parseNaturalLanguage(q.trim(), clusters) : null),
    [needle, q, clusters],
  )

  if (!open) return null

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center bg-black/60 pt-[15vh] backdrop-blur-sm palette-overlay">
      <div className="glass-panel-lg w-full max-w-lg overflow-hidden shadow-2xl palette-panel">
        <input
          autoFocus
          className="w-full border-b border-glass-border bg-transparent px-4 py-3 outline-none"
          placeholder="Search clusters, commands, AI ask, or natural language…"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && nlParsed) {
              e.preventDefault()
              if (nlParsed.kind === 'run') {
                onSelect({
                  kind: 'run',
                  cluster: nlParsed.cluster,
                  command: nlParsed.command,
                  args: nlParsed.args,
                })
              } else if (nlParsed.kind === 'open') {
                onSelect({ kind: 'detail', cluster: nlParsed.cluster })
              } else if (nlParsed.kind === 'ai') {
                onSelect({ kind: 'ai', query: nlParsed.query })
              }
              onClose()
            }
          }}
        />
        <div className="max-h-80 overflow-y-auto p-2">
          {needle.length >= 2 && (
            <div className="mb-3 border-b border-glass-border pb-2">
              <p className="px-2 py-1 text-xs font-semibold text-glass-purple">AI & natural language</p>
              {nlParsed?.kind === 'run' && (
                <button
                  type="button"
                  className="search-result-row block w-full rounded-xl px-3 py-2 text-left text-sm hover:bg-glass-purple/15"
                  onClick={() => {
                    onSelect({
                      kind: 'run',
                      cluster: nlParsed.cluster,
                      command: nlParsed.command,
                      args: nlParsed.args,
                    })
                    onClose()
                  }}
                >
                  Run {nlParsed.command} on {nlParsed.cluster.name}
                </button>
              )}
              {nlParsed?.kind === 'open' && (
                <button
                  type="button"
                  className="search-result-row block w-full rounded-xl px-3 py-2 text-left text-sm hover:bg-glass-purple/15"
                  onClick={() => {
                    onSelect({ kind: 'detail', cluster: nlParsed.cluster })
                    onClose()
                  }}
                >
                  Open {nlParsed.cluster.name}
                </button>
              )}
              <button
                type="button"
                className="search-result-row block w-full rounded-xl px-3 py-2 text-left text-sm hover:bg-glass-purple/15"
                onClick={() => {
                  onSelect({ kind: 'ai', query: q.trim() })
                  onClose()
                }}
              >
                Ask AI Copilot: {q.trim().slice(0, 60)}
                {q.trim().length > 60 ? '…' : ''}
              </button>
              <p className="px-2 py-1 text-[10px] text-glass-muted">{nlCommandHint()}</p>
            </div>
          )}
          {filteredApp.length > 0 && (
            <div className="mb-3">
              <p className="px-2 py-1 text-xs font-semibold text-glass-muted">App</p>
              {filteredApp.map((action) => (
                <button
                  key={action.id}
                  type="button"
                  className="search-result-row block w-full rounded-xl px-3 py-2 text-left text-sm"
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
                    className="search-result-row block w-full rounded-xl px-3 py-2 text-left text-sm"
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
                    className="search-result-row block w-full rounded-xl px-3 py-2 text-left text-sm"
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
