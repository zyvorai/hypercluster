import type { ClusterSpec } from '../lib/types'
import { estimateInstallMinutes, installPlan } from '../lib/clusterSpec'
import { GlassCard } from './GlassCard'

export function LivePreviewPanel({ spec }: { spec: ClusterSpec }) {
  const nodes = spec.nodes.length || spec.controlPlaneIps.length + spec.workerIps.length
  const plan = installPlan(spec)
  const mins = estimateInstallMinutes(spec)

  return (
    <GlassCard className="sticky top-4 space-y-4">
      <h3 className="font-medium">Live preview</h3>
      <dl className="space-y-2 text-sm">
        <div>
          <dt className="text-glass-muted">Cluster</dt>
          <dd className="font-medium">{spec.clusterName || '—'}</dd>
        </div>
        <div>
          <dt className="text-glass-muted">Topology</dt>
          <dd>
            {spec.controlPlaneIps.length} CP · {spec.workerIps.length} workers · {nodes} nodes
          </dd>
        </div>
        <div>
          <dt className="text-glass-muted">Distro</dt>
          <dd>{spec.k8sDistro}</dd>
        </div>
        <div>
          <dt className="text-glass-muted">CNI</dt>
          <dd>{spec.cniPlugin}</dd>
        </div>
        <div>
          <dt className="text-glass-muted">Version</dt>
          <dd>{spec.kubeVersion}</dd>
        </div>
        <div>
          <dt className="text-glass-muted">Est. duration</dt>
          <dd>~{mins} min</dd>
        </div>
      </dl>
      <div>
        <p className="mb-1 text-xs text-glass-muted">Platform stack</p>
        <ul className="flex flex-wrap gap-1">
          {plan.map((item) => (
            <li
              key={item}
              className="rounded-lg bg-white/5 px-2 py-0.5 text-xs text-glass-muted"
            >
              {item}
            </li>
          ))}
        </ul>
      </div>
      {spec.metallbEnabled && (
        <p className="text-xs text-glass-muted">MetalLB: {spec.metallbIpPool || 'pool not set'}</p>
      )}
    </GlassCard>
  )
}
