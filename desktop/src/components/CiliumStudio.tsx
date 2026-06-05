import type { ClusterSpec } from '../lib/types'
import { GlassCard } from './GlassCard'

export function CiliumStudio({
  spec,
  onChange,
}: {
  spec: ClusterSpec
  onChange: (spec: ClusterSpec) => void
}) {
  const networkModes = [
    {
      id: 'ebpf',
      label: 'eBPF (Recommended)',
      description: 'Cilium kube-proxy replacement — lower latency, Hubble-ready.',
      active: spec.cniPlugin === 'cilium',
    },
    {
      id: 'calico',
      label: 'Calico',
      description: 'Traditional overlay — Kubespray native path.',
      active: spec.cniPlugin === 'calico',
    },
    {
      id: 'flannel',
      label: 'Flannel',
      description: 'Simple overlay for minimal clusters.',
      active: spec.cniPlugin === 'flannel',
    },
  ] as const

  return (
    <GlassCard className="space-y-4">
      <h3 className="font-medium">Network mode</h3>
      <div className="space-y-2">
        {networkModes.map((mode) => (
          <label
            key={mode.id}
            className={`flex cursor-pointer gap-3 rounded-xl border p-3 ${
              mode.active ? 'border-glass-accent/50 bg-glass-accent/10' : 'border-glass-border'
            }`}
          >
            <input
              type="radio"
              name="cni"
              checked={mode.active}
              onChange={() =>
                onChange({
                  ...spec,
                  cniPlugin: mode.id === 'ebpf' ? 'cilium' : mode.id,
                })
              }
              className="mt-1"
            />
            <span>
              <span className="font-medium">{mode.label}</span>
              <span className="block text-xs text-glass-muted">{mode.description}</span>
            </span>
          </label>
        ))}
      </div>

      {spec.cniPlugin === 'cilium' && (
        <div>
          <h4 className="mb-2 text-sm font-medium text-glass-muted">Cilium studio</h4>
          <div className="grid gap-2 sm:grid-cols-2">
            {(
              [
                ['ciliumHubble', 'Hubble', 'Flow observability'],
                ['ciliumWireguard', 'WireGuard', 'Encrypted node traffic'],
                ['ciliumBgp', 'BGP', 'LoadBalancer peering'],
                ['ciliumGatewayApi', 'Gateway API', 'Ingress & gateway routes'],
              ] as const
            ).map(([key, label, desc]) => (
              <label key={key} className="flex items-start gap-2 rounded-lg bg-black/10 p-2 text-sm">
                <input
                  type="checkbox"
                  checked={spec[key]}
                  onChange={(e) => onChange({ ...spec, [key]: e.target.checked })}
                  className="mt-0.5"
                />
                <span>
                  <span className="font-medium">{label}</span>
                  <span className="block text-xs text-glass-muted">{desc}</span>
                </span>
              </label>
            ))}
          </div>
        </div>
      )}

      <details>
        <summary className="cursor-pointer text-sm text-glass-muted">Advanced CIDRs</summary>
        <div className="mt-2 space-y-2">
          <input
            className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2 text-sm"
            value={spec.kubePodsSubnet}
            onChange={(e) => onChange({ ...spec, kubePodsSubnet: e.target.value })}
            placeholder="Pod CIDR"
          />
          <input
            className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2 text-sm"
            value={spec.kubeServiceAddresses}
            onChange={(e) => onChange({ ...spec, kubeServiceAddresses: e.target.value })}
            placeholder="Service CIDR"
          />
        </div>
      </details>
    </GlassCard>
  )
}
