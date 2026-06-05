import type { ClusterSpec } from '../lib/types'
import { GlassCard } from './GlassCard'

type MarketCard = {
  key: keyof ClusterSpec
  label: string
  description: string
  comingSoon?: boolean
}

const MARKETPLACE: { category: string; items: MarketCard[] }[] = [
  {
    category: 'Core platform',
    items: [
      { key: 'certManagerEnabled', label: 'cert-manager', description: 'TLS certificates' },
      { key: 'metricsServerEnabled', label: 'metrics-server', description: 'Resource metrics' },
      { key: 'metallbEnabled', label: 'MetalLB', description: 'LoadBalancer IPs' },
      { key: 'ingressNginxEnabled', label: 'ingress-nginx', description: 'HTTP ingress' },
    ],
  },
  {
    category: 'Virtualization',
    items: [
      { key: 'kubevirtEnabled', label: 'KubeVirt', description: 'VM workloads' },
      { key: 'cnaoEnabled', label: 'CNAO', description: 'Multus CNI' },
      { key: 'sspEnabled', label: 'SSP', description: 'Scheduling profiles' },
    ],
  },
  {
    category: 'Storage',
    items: [
      { key: 'longhornEnabled', label: 'Longhorn', description: 'Distributed block storage' },
    ],
  },
  {
    category: 'Networking (Cilium)',
    items: [
      { key: 'ciliumHubble', label: 'Hubble', description: 'Observability' },
      { key: 'ciliumWireguard', label: 'WireGuard', description: 'Encrypted overlay' },
      { key: 'ciliumBgp', label: 'BGP', description: 'Peering' },
      { key: 'ciliumGatewayApi', label: 'Gateway API', description: 'Ingress gateway' },
    ],
  },
  {
    category: 'AI / GPU',
    items: [
      { key: 'gpuOperatorEnabled', label: 'GPU Operator', description: 'NVIDIA GPUs' },
      { key: 'nfdEnabled', label: 'NFD', description: 'Node features' },
    ],
  },
]

const COMING_SOON: { category: string; labels: string[] }[] = [
  { category: 'Storage', labels: ['Ceph', 'OpenEBS', 'NFS'] },
  { category: 'AI / GPU', labels: ['vLLM', 'KServe', 'Ray'] },
  { category: 'Security', labels: ['Kyverno', 'Falco', 'Trivy'] },
  { category: 'Observability', labels: ['Prometheus', 'Grafana', 'Loki'] },
]

function StackCard({
  item,
  checked,
  onToggle,
}: {
  item: MarketCard
  checked: boolean
  onToggle: () => void
}) {
  return (
    <label
      className={`flex cursor-pointer gap-3 rounded-xl border p-3 ${
        checked ? 'border-glass-accent/50 bg-glass-accent/10' : 'border-glass-border bg-black/10'
      }`}
    >
      <input type="checkbox" checked={checked} onChange={onToggle} className="mt-1" />
      <span>
        <span className="block font-medium">{item.label}</span>
        <span className="text-xs text-glass-muted">{item.description}</span>
      </span>
    </label>
  )
}

export function PlatformStackCards({
  spec,
  onChange,
}: {
  spec: ClusterSpec
  onChange: (spec: ClusterSpec) => void
}) {
  return (
    <GlassCard className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h3 className="font-medium">Platform stack marketplace</h3>
          <p className="text-xs text-glass-muted">Intent-driven installs — maps to Helm platform-stack</p>
        </div>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={spec.platformStackEnabled}
            onChange={(e) => onChange({ ...spec, platformStackEnabled: e.target.checked })}
          />
          Enable stack
        </label>
      </div>

      {spec.metallbEnabled && (
        <input
          className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2 text-sm"
          placeholder="MetalLB IP pool"
          value={spec.metallbIpPool}
          onChange={(e) => onChange({ ...spec, metallbIpPool: e.target.value })}
        />
      )}

      {spec.kubevirtEnabled && (
        <div className="grid gap-2 sm:grid-cols-2">
          <input
            className="rounded-xl border border-glass-border bg-black/20 px-3 py-2 text-sm"
            placeholder="KubeVirt version"
            value={spec.kubevirtVersion}
            onChange={(e) => onChange({ ...spec, kubevirtVersion: e.target.value })}
          />
          <input
            className="rounded-xl border border-glass-border bg-black/20 px-3 py-2 text-sm"
            placeholder="CDI version"
            value={spec.cdiVersion}
            onChange={(e) => onChange({ ...spec, cdiVersion: e.target.value })}
          />
        </div>
      )}

      {MARKETPLACE.map((section) => (
        <div key={section.category}>
          <h4 className="mb-2 text-sm font-medium text-glass-muted">{section.category}</h4>
          <div className="grid gap-2 sm:grid-cols-2">
            {section.items.map((item) => (
              <StackCard
                key={item.label}
                item={item}
                checked={Boolean(spec[item.key])}
                onToggle={() => onChange({ ...spec, [item.key]: !spec[item.key] })}
              />
            ))}
          </div>
        </div>
      ))}

      {COMING_SOON.map((section) => (
        <div key={section.category}>
          <h4 className="mb-2 text-sm font-medium text-glass-muted">{section.category}</h4>
          <div className="flex flex-wrap gap-2">
            {section.labels.map((label) => (
              <span
                key={label}
                className="rounded-lg border border-dashed border-glass-border px-3 py-1.5 text-xs text-glass-muted"
              >
                {label} <span className="text-amber-200/80">Soon</span>
              </span>
            ))}
          </div>
        </div>
      ))}
    </GlassCard>
  )
}
