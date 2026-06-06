import type { ClusterSpec } from '../lib/types'
import { GlassCard } from './GlassCard'

/** Single-node k3s lab tuning — maps to LAB_* in cluster.conf */
export function LabOpsFields({
  spec,
  onChange,
}: {
  spec: ClusterSpec
  onChange: (spec: ClusterSpec) => void
}) {
  if (spec.k8sDistro !== 'k3s') return null

  return (
    <GlassCard className="space-y-3">
      <h3 className="font-medium">Lab operations</h3>
      <p className="text-sm text-glass-muted">
        Secondary disk for KubeVirt PVCs and memory tuning on single-node stacks. Runs via{' '}
        <code className="text-xs">hypercluster lab</code> after deploy.
      </p>
      <label className="flex items-center gap-2 text-sm">
        <input
          type="checkbox"
          checked={spec.labAutoSetup}
          onChange={(e) => onChange({ ...spec, labAutoSetup: e.target.checked })}
        />
        Auto lab setup after deploy (storage + memory tune when enabled below)
      </label>
      <label className="flex items-center gap-2 text-sm">
        <input
          type="checkbox"
          checked={spec.labMemoryTuneEnabled}
          onChange={(e) => onChange({ ...spec, labMemoryTuneEnabled: e.target.checked })}
        />
        Memory tune (scale HA replicas to 1)
      </label>
      <div className="grid gap-3 sm:grid-cols-2">
        <input
          className="rounded-xl border border-glass-border bg-black/20 px-3 py-2 text-sm"
          value={spec.labSecondaryDisk}
          onChange={(e) => onChange({ ...spec, labSecondaryDisk: e.target.value })}
          placeholder="Secondary disk (e.g. /dev/sdb)"
        />
        <input
          className="rounded-xl border border-glass-border bg-black/20 px-3 py-2 text-sm"
          value={spec.labKubevirtStorageClass}
          onChange={(e) => onChange({ ...spec, labKubevirtStorageClass: e.target.value })}
          placeholder="StorageClass name"
        />
      </div>
      <label className="flex items-center gap-2 text-sm">
        <input
          type="checkbox"
          checked={spec.labStorageFormat}
          onChange={(e) => onChange({ ...spec, labStorageFormat: e.target.checked })}
        />
        Allow formatting empty secondary disk (destructive)
      </label>
    </GlassCard>
  )
}
