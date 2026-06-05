import { useMemo, useState } from 'react'
import { motion } from 'framer-motion'
import type { ClusterNode, ClusterSpec, NodeRole } from '../lib/types'
import { syncIpsFromNodes } from '../lib/clusterSpec'

const ROLE_COLORS: Record<NodeRole, string> = {
  'control-plane': 'border-blue-400/50 bg-blue-500/10',
  worker: 'border-emerald-400/50 bg-emerald-500/10',
  etcd: 'border-amber-400/50 bg-amber-500/10',
}

function defaultPosition(node: ClusterNode, index: number, role: NodeRole): { x: number; y: number } {
  if (node.position) return node.position
  const col = index % 3
  const row = Math.floor(index / 3)
  const yBase = role === 'control-plane' ? 40 : role === 'etcd' ? 200 : 280
  return { x: 40 + col * 180, y: yBase + row * 20 }
}

export function TopologyCanvas({
  spec,
  onChange,
}: {
  spec: ClusterSpec
  onChange: (spec: ClusterSpec) => void
}) {
  const [dragging, setDragging] = useState<string | null>(null)
  const nodes = spec.nodes

  const grouped = useMemo(() => {
    const cp = nodes.filter((n) => n.roles.includes('control-plane'))
    const etcd = nodes.filter((n) => n.roles.includes('etcd') && !n.roles.includes('control-plane'))
    const workers = nodes.filter((n) => n.roles.includes('worker') && !n.roles.includes('control-plane'))
    return { cp, etcd, workers }
  }, [nodes])

  const updateNode = (id: string, patch: Partial<ClusterNode>) => {
    onChange(
      syncIpsFromNodes({
        ...spec,
        nodes: nodes.map((n) => (n.id === id ? { ...n, ...patch } : n)),
      }),
    )
  }

  if (nodes.length === 0) {
    return (
      <p className="rounded-xl border border-dashed border-glass-border p-6 text-center text-sm text-glass-muted">
        Add nodes below to see the topology canvas. Drag cards to arrange your architecture.
      </p>
    )
  }

  const renderGroup = (title: string, list: ClusterNode[], role: NodeRole) => (
    <div className="mb-2">
      <p className="mb-1 text-xs font-medium uppercase tracking-wide text-glass-muted">{title}</p>
      <div className="relative min-h-[120px] rounded-xl border border-glass-border/50 bg-black/10">
        {list.map((node, i) => {
          const pos = defaultPosition(node, i, role)
          return (
            <motion.div
              key={node.id}
              drag
              dragMomentum={false}
              onDragStart={() => setDragging(node.id)}
              onDragEnd={(_, info) => {
                setDragging(null)
                updateNode(node.id, {
                  position: {
                    x: Math.max(0, pos.x + info.offset.x),
                    y: Math.max(0, pos.y + info.offset.y),
                  },
                })
              }}
              style={{ position: 'absolute', left: pos.x, top: pos.y }}
              className={`w-40 cursor-grab rounded-xl border p-2 text-xs shadow-lg active:cursor-grabbing ${
                ROLE_COLORS[role]
              } ${dragging === node.id ? 'z-10 ring-2 ring-glass-accent' : ''}`}
            >
              <p className="font-medium">{node.hostname}</p>
              <p className="text-glass-muted">{node.ip}</p>
              <div className="mt-1 flex flex-wrap gap-0.5">
                {node.roles.map((r) => (
                  <span key={r} className="rounded bg-black/20 px-1 text-[10px]">
                    {r}
                  </span>
                ))}
              </div>
              {node.gpu && <span className="mt-1 block text-[10px] text-amber-200">GPU</span>}
            </motion.div>
          )
        })}
      </div>
    </div>
  )

  return (
    <div className="space-y-3">
      <p className="text-xs text-glass-muted">Drag nodes to design your cluster layout.</p>
      {renderGroup('Control plane', grouped.cp, 'control-plane')}
      {grouped.etcd.length > 0 && renderGroup('etcd', grouped.etcd, 'etcd')}
      {renderGroup('Workers', grouped.workers, 'worker')}
    </div>
  )
}
