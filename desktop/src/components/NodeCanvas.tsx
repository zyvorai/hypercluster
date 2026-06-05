import { lazy, Suspense, useRef, useState } from 'react'
import type { ClusterNode, ClusterSpec, DiscoverJson, DiscoverNode, HaPreset, NodeRole } from '../lib/types'
import { discoverJson, pickSshKey } from '../lib/api'
import { syncIpsFromNodes, syncNodesFromIps } from '../lib/clusterSpec'
import { HaAdvisor } from './HaAdvisor'
import { GlassCard } from './GlassCard'
import { IpTags } from './IpTags'

const TopologyCanvas = lazy(() =>
  import('./TopologyCanvas').then((m) => ({ default: m.TopologyCanvas })),
)

function newNode(ip: string, role: 'control-plane' | 'worker', idx: number): ClusterNode {
  return {
    id: `${role}-${idx}-${Date.now()}`,
    hostname: role === 'control-plane' ? `cp-${idx + 1}` : `worker-${idx + 1}`,
    ip,
    roles: [role],
  }
}

function applyHaPreset(spec: ClusterSpec, preset: HaPreset): ClusterSpec {
  if (preset === 'custom') return { ...spec, haControlPlane: preset }
  const cpCount = preset === 'single' ? 1 : preset === '3' ? 3 : 5
  const existing = spec.controlPlaneIps.slice(0, cpCount)
  while (existing.length < cpCount) {
    existing.push(`10.0.0.${10 + existing.length}`)
  }
  const nodes: ClusterNode[] = existing.map((ip, i) => newNode(ip, 'control-plane', i))
  spec.workerIps.forEach((ip, i) => nodes.push(newNode(ip, 'worker', i)))
  return syncIpsFromNodes({ ...spec, haControlPlane: preset, nodes, controlPlaneIps: existing })
}

function parseCsv(text: string): ClusterNode[] {
  const valid = new Set<NodeRole>(['control-plane', 'worker', 'etcd'])
  return text
    .split('\n')
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith('#'))
    .map((line, i) => {
      const [hostname, ip, rolesRaw] = line.split(',').map((s) => s.trim().replace(/^"|"$/g, ''))
      const roles = (rolesRaw || 'worker')
        .split(/[\s|]+/)
        .filter((r): r is NodeRole => valid.has(r as NodeRole))
      return {
        id: `csv-${i}`,
        hostname: hostname || `node-${i + 1}`,
        ip: ip || hostname,
        roles: roles.length ? roles : (['worker'] as NodeRole[]),
      }
    })
    .filter((n): n is ClusterNode => Boolean(n.ip))
}

export function NodeCanvas({
  spec,
  onChange,
}: {
  spec: ClusterSpec
  onChange: (spec: ClusterSpec) => void
}) {
  const [discoverSource, setDiscoverSource] = useState('libvirt')
  const [discoverCidr, setDiscoverCidr] = useState('192.168.1.0/24')
  const [discovering, setDiscovering] = useState(false)
  const [discovered, setDiscovered] = useState<DiscoverNode[]>([])
  const [discoverValidations, setDiscoverValidations] = useState<DiscoverJson['validations']>()
  const [validateHosts, setValidateHosts] = useState(false)
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const fileRef = useRef<HTMLInputElement>(null)

  const nodesSpec = syncNodesFromIps(spec)
  const nodes = nodesSpec.nodes

  const setNodes = (next: ClusterNode[]) => {
    onChange(syncIpsFromNodes({ ...spec, nodes: next }))
  }

  const runDiscover = async () => {
    setDiscovering(true)
    try {
      const result = await discoverJson({
        source: discoverSource,
        cidr: discoverSource === 'ssh-scan' ? discoverCidr : undefined,
        validate: validateHosts,
        probe: validateHosts,
        sshUser: spec.sshUser,
        sshKey: spec.sshKey,
        sshPort: spec.sshPort,
      })
      setDiscovered(result.nodes)
      setDiscoverValidations(result.validations)
      setSelected(new Set(result.nodes.map((n) => n.ip)))
    } catch (e) {
      window.alert(String(e))
    } finally {
      setDiscovering(false)
    }
  }

  const importDiscovered = () => {
    const picked = discovered.filter((n) => selected.has(n.ip))
    const imported: ClusterNode[] = picked.map((n, i) => ({
      id: `disc-${i}`,
      hostname: n.name,
      ip: n.ip,
      roles: i === 0 ? ['control-plane'] : ['worker'],
      gpu: n.gpu,
    }))
    setNodes(imported)
    setDiscovered([])
  }

  const onCsv = (file: File) => {
    const reader = new FileReader()
    reader.onload = () => {
      const parsed = parseCsv(String(reader.result))
      if (parsed.length) setNodes(parsed)
    }
    reader.readAsText(file)
  }

  return (
    <div className="space-y-4">
      <HaAdvisor
        spec={nodesSpec}
        onApply={(preset) => onChange(applyHaPreset(spec, preset))}
      />

      {nodes.length > 0 && (
        <GlassCard>
          <h3 className="mb-3 font-medium">Architecture designer</h3>
          <Suspense fallback={<p className="text-sm text-glass-muted">Loading canvas…</p>}>
            <TopologyCanvas spec={spec} onChange={onChange} />
          </Suspense>
        </GlassCard>
      )}

      <GlassCard className="space-y-3">
        <h3 className="font-medium">Control plane layout</h3>
        <div className="flex flex-wrap gap-2">
          {(['single', '3', '5', 'custom'] as HaPreset[]).map((p) => (
            <button
              key={p}
              type="button"
              className={`rounded-xl px-3 py-1.5 text-sm ${
                spec.haControlPlane === p ? 'bg-glass-accent/30' : 'bg-white/5'
              }`}
              onClick={() => onChange(applyHaPreset(spec, p))}
            >
              {p === 'single' ? 'Single' : p === 'custom' ? 'Custom' : `${p}-node HA`}
            </button>
          ))}
        </div>
      </GlassCard>

      <GlassCard className="space-y-3">
        <h3 className="font-medium">Discover infrastructure</h3>
        <div className="flex flex-wrap gap-2">
          <select
            className="rounded-xl border border-glass-border bg-black/20 px-3 py-2 text-sm"
            value={discoverSource}
            onChange={(e) => setDiscoverSource(e.target.value)}
          >
            <option value="libvirt">libvirt</option>
            <option value="proxmox">Proxmox</option>
            <option value="vmware">VMware (govc)</option>
            <option value="ssh-scan">ssh-scan</option>
            <option value="csv">CSV file</option>
          </select>
          {discoverSource === 'ssh-scan' && (
            <input
              className="rounded-xl border border-glass-border bg-black/20 px-3 py-2 text-sm"
              value={discoverCidr}
              onChange={(e) => setDiscoverCidr(e.target.value)}
              placeholder="CIDR"
            />
          )}
          {discoverSource === 'csv' ? (
            <>
              <input ref={fileRef} type="file" accept=".csv" className="hidden" onChange={(e) => {
                const f = e.target.files?.[0]
                if (f) onCsv(f)
              }} />
              <button type="button" className="btn-ghost text-sm" onClick={() => fileRef.current?.click()}>
                Import CSV…
              </button>
            </>
          ) : (
            <button type="button" className="btn-primary text-sm" disabled={discovering} onClick={runDiscover}>
              {discovering ? 'Scanning…' : 'Discover'}
            </button>
          )}
          {discoverSource !== 'csv' && (
            <label className="flex items-center gap-2 text-xs text-glass-muted">
              <input
                type="checkbox"
                checked={validateHosts}
                onChange={(e) => setValidateHosts(e.target.checked)}
              />
              Validate hosts (KVM, VT-x, IOMMU…)
            </label>
          )}
        </div>
        {discovered.length > 0 && (
          <div className="space-y-2">
            <ul className="max-h-48 space-y-1 overflow-y-auto text-sm">
              {discovered.map((n) => (
                <li key={n.ip} className="rounded-lg bg-black/10 px-2 py-1">
                  <label className="flex items-center gap-2">
                    <input
                      type="checkbox"
                      checked={selected.has(n.ip)}
                      onChange={(e) => {
                        const next = new Set(selected)
                        if (e.target.checked) next.add(n.ip)
                        else next.delete(n.ip)
                        setSelected(next)
                      }}
                    />
                    <span>
                      <strong>{n.name}</strong> · {n.ip} ({n.source})
                      {n.vcpu != null && (
                        <span className="ml-1 text-glass-muted">
                          {n.vcpu} vCPU · {n.memoryMb ?? '?'} MB
                          {n.storageGb ? ` · ${n.storageGb} GB disk` : ''}
                          {n.gpu ? ' · GPU' : ''}
                        </span>
                      )}
                    </span>
                  </label>
                </li>
              ))}
            </ul>
            {discoverValidations && discoverValidations.length > 0 && (
              <div className="rounded-lg border border-glass-border p-2 text-xs">
                <p className="mb-1 font-medium text-glass-accent">Host validation</p>
                {discoverValidations.map((v) => (
                  <div key={v.ip} className="mb-1">
                    <p className="text-glass-muted">{v.ip}</p>
                    {v.checks.map((c) => (
                      <p key={c.name} className={c.passed ? 'text-emerald-300' : 'text-red-300'}>
                        {c.passed ? '✓' : '✗'} {c.name}
                        {c.detail ? ` — ${c.detail}` : ''}
                      </p>
                    ))}
                  </div>
                ))}
              </div>
            )}
            <button type="button" className="btn-primary text-sm" onClick={importDiscovered}>
              Import selected
            </button>
          </div>
        )}
      </GlassCard>

      <GlassCard className="space-y-4">
        <h3 className="font-medium">Nodes</h3>
        {nodes.length === 0 ? (
          <div className="space-y-3">
            <IpTags
              label="Control plane IPs"
              ips={spec.controlPlaneIps}
              onChange={(ips) => onChange({ ...spec, controlPlaneIps: ips, nodes: [] })}
            />
            <IpTags
              label="Worker IPs"
              ips={spec.workerIps}
              onChange={(ips) => onChange({ ...spec, workerIps: ips, nodes: [] })}
            />
          </div>
        ) : (
          <div className="grid gap-3 sm:grid-cols-2">
            {nodes.map((node, idx) => (
              <div key={node.id} className="rounded-xl border border-glass-border bg-black/10 p-3">
                <input
                  className="mb-2 w-full rounded-lg border border-glass-border bg-black/20 px-2 py-1 text-sm"
                  value={node.hostname}
                  onChange={(e) => {
                    const next = [...nodes]
                    next[idx] = { ...node, hostname: e.target.value }
                    setNodes(next)
                  }}
                />
                <input
                  className="mb-2 w-full rounded-lg border border-glass-border bg-black/20 px-2 py-1 text-sm"
                  value={node.ip}
                  onChange={(e) => {
                    const next = [...nodes]
                    next[idx] = { ...node, ip: e.target.value }
                    setNodes(next)
                  }}
                />
                <div className="mb-2 flex flex-wrap gap-1">
                  {(['control-plane', 'worker', 'etcd'] as const).map((role) => (
                    <button
                      key={role}
                      type="button"
                      className={`rounded px-2 py-0.5 text-xs ${
                        node.roles.includes(role) ? 'bg-glass-accent/30' : 'bg-white/5'
                      }`}
                      onClick={() => {
                        const roles = node.roles.includes(role)
                          ? node.roles.filter((r) => r !== role)
                          : [...node.roles, role]
                        const next = [...nodes]
                        next[idx] = { ...node, roles: roles.length ? roles : ['worker'] }
                        setNodes(next)
                      }}
                    >
                      {role}
                    </button>
                  ))}
                </div>
                <details className="text-xs">
                  <summary className="cursor-pointer text-glass-muted">Per-node SSH</summary>
                  <div className="mt-2 space-y-1">
                    <input
                      className="w-full rounded border border-glass-border bg-black/20 px-2 py-1"
                      placeholder={`User (default ${spec.sshUser})`}
                      value={node.sshUser ?? ''}
                      onChange={(e) => {
                        const next = [...nodes]
                        next[idx] = { ...node, sshUser: e.target.value || undefined }
                        setNodes(next)
                      }}
                    />
                    <input
                      className="w-full rounded border border-glass-border bg-black/20 px-2 py-1"
                      placeholder="SSH key override"
                      value={node.sshKey ?? ''}
                      onChange={(e) => {
                        const next = [...nodes]
                        next[idx] = { ...node, sshKey: e.target.value || undefined }
                        setNodes(next)
                      }}
                    />
                  </div>
                </details>
              </div>
            ))}
          </div>
        )}
      </GlassCard>

      <GlassCard className="space-y-3">
        <h3 className="font-medium">Cluster SSH defaults</h3>
        <input
          className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2"
          value={spec.sshUser}
          onChange={(e) => onChange({ ...spec, sshUser: e.target.value })}
          placeholder="SSH user"
        />
        <div className="flex gap-2">
          <input
            className="flex-1 rounded-xl border border-glass-border bg-black/20 px-3 py-2"
            value={spec.sshKey}
            onChange={(e) => onChange({ ...spec, sshKey: e.target.value })}
            placeholder="SSH key path"
          />
          <button
            type="button"
            className="btn-ghost shrink-0"
            onClick={async () => {
              const path = await pickSshKey()
              if (path) onChange({ ...spec, sshKey: path })
            }}
          >
            Browse…
          </button>
        </div>
        <input
          className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2"
          type="number"
          value={spec.sshPort}
          onChange={(e) => onChange({ ...spec, sshPort: Number(e.target.value) || 22 })}
          placeholder="SSH port"
        />
      </GlassCard>
    </div>
  )
}
