import { useMemo, useState } from 'react'
import type { ClusterEntry, StatusJson, VmsJson } from '../lib/types'

export type SearchResult =
  | { kind: 'cluster'; cluster: ClusterEntry; label: string }
  | { kind: 'node'; cluster: ClusterEntry; name: string; label: string }
  | { kind: 'vm'; cluster: ClusterEntry; name: string; namespace: string; label: string }
  | { kind: 'action'; action: string; label: string }

export function buildSearchIndex(
  clusters: ClusterEntry[],
  nodeData: Record<string, StatusJson | null>,
  vmsData: Record<string, VmsJson | null>,
): SearchResult[] {
  const items: SearchResult[] = []
  for (const c of clusters) {
    items.push({ kind: 'cluster', cluster: c, label: c.name })
    const status = nodeData[c.name]
    if (status) {
      for (const n of status.nodes) {
        items.push({
          kind: 'node',
          cluster: c,
          name: n.name,
          label: `${c.name} · node ${n.name}`,
        })
      }
    }
    const vms = vmsData[c.name]
    if (vms) {
      for (const vm of vms.vms) {
        items.push({
          kind: 'vm',
          cluster: c,
          name: vm.name,
          namespace: vm.namespace,
          label: `${c.name} · VM ${vm.namespace}/${vm.name}`,
        })
      }
      for (const t of vms.templates) {
        items.push({
          kind: 'action',
          action: `template:${t.id}`,
          label: `Template ${t.label}`,
        })
      }
    }
  }
  items.push(
    { kind: 'action', action: 'create-hub', label: 'Create cluster' },
    { kind: 'action', action: 'quick-virt', label: 'Quick Deploy — Virtualization' },
    { kind: 'action', action: 'import-conf', label: 'Import cluster.conf' },
  )
  return items
}

export function GlobalSearch({
  open,
  onClose,
  index,
  onSelect,
}: {
  open: boolean
  onClose: () => void
  index: SearchResult[]
  onSelect: (result: SearchResult) => void
}) {
  const [q, setQ] = useState('')

  const filtered = useMemo(() => {
    const needle = q.trim().toLowerCase()
    if (!needle) return index.slice(0, 40)
    return index.filter((i) => i.label.toLowerCase().includes(needle)).slice(0, 50)
  }, [index, q])

  if (!open) return null

  return (
    <div className="fixed inset-0 z-[60] flex items-start justify-center bg-black/60 pt-[12vh] backdrop-blur-sm">
      <div className="glass-panel-lg w-full max-w-xl overflow-hidden shadow-2xl">
        <input
          autoFocus
          className="w-full border-b border-glass-border bg-transparent px-4 py-3 outline-none"
          placeholder="Search nodes, VMs, clusters, templates…"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          onKeyDown={(e) => e.key === 'Escape' && onClose()}
        />
        <ul className="max-h-96 overflow-y-auto p-2">
          {filtered.map((item, i) => (
            <li key={`${item.kind}-${i}`}>
              <button
                type="button"
                className="block w-full rounded-lg px-3 py-2 text-left text-sm hover:bg-white/10"
                onClick={() => {
                  onSelect(item)
                  onClose()
                }}
              >
                <span className="text-[10px] uppercase text-glass-muted">{item.kind}</span>
                <span className="block">{item.label}</span>
              </button>
            </li>
          ))}
        </ul>
      </div>
    </div>
  )
}
