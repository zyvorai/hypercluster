import type { ClusterSpec, KubeVirtTemplate, VmsJson } from '../lib/types'
import { GlassCard } from './GlassCard'

export function KubeVirtStudio({
  spec,
  vms,
  onChange,
  onRefreshVms,
  onCreateFromTemplate,
  loading,
  readOnly,
}: {
  spec: ClusterSpec
  vms: VmsJson | null
  onChange: (spec: ClusterSpec) => void
  onRefreshVms?: () => void
  onCreateFromTemplate?: (templateId: string, name: string) => void
  loading?: boolean
  readOnly?: boolean
}) {
  const templates = vms?.templates ?? []

  return (
    <div className="space-y-4">
      <GlassCard className="space-y-3">
        <h3 className="font-medium">VM platform</h3>
        <div className="grid gap-2 sm:grid-cols-2">
          {(
            [
              ['kubevirtEnabled', 'KubeVirt', 'VM workloads on Kubernetes'],
              ['cnaoEnabled', 'CNAO', 'Multus / additional networks'],
              ['sspEnabled', 'SSP', 'Scheduling profiles'],
            ] as const
          ).map(([key, label, desc]) => (
            <label key={key} className="flex gap-2 rounded-xl border border-glass-border p-3 text-sm">
              <input
                type="checkbox"
                checked={spec[key]}
                disabled={readOnly}
                onChange={(e) => onChange({ ...spec, [key]: e.target.checked })}
              />
              <span>
                <span className="font-medium">{label}</span>
                <span className="block text-xs text-glass-muted">{desc}</span>
              </span>
            </label>
          ))}
        </div>
      </GlassCard>

      <GlassCard>
        <h3 className="mb-3 font-medium">Advanced (preview)</h3>
        <div className="flex flex-wrap gap-2 text-xs">
          {['Live Migration', 'GPU Passthrough', 'SR-IOV', 'NUMA', 'HugePages', 'VirtIOFS'].map(
            (f) => (
              <span key={f} className="rounded-lg border border-dashed border-glass-border px-2 py-1">
                {f} <span className="text-amber-200/80">Soon</span>
              </span>
            ),
          )}
        </div>
      </GlassCard>

      <GlassCard>
        <div className="mb-3 flex items-center justify-between">
          <h3 className="font-medium">VM template catalog</h3>
          {onRefreshVms && (
            <button type="button" className="text-xs text-glass-accent" onClick={onRefreshVms} disabled={loading}>
              Refresh VMs
            </button>
          )}
        </div>
        <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
          {templates.map((t: KubeVirtTemplate) => (
            <div
              key={t.id}
              className="rounded-xl border border-glass-border bg-black/10 p-3 text-sm"
            >
              <div className="flex items-center justify-between">
                <span className="font-medium">{t.label}</span>
                {t.preview && (
                  <span className="text-[10px] text-amber-200">Preview</span>
                )}
              </div>
              <p className="text-xs text-glass-muted">{t.description ?? t.os}</p>
              {t.defaultCpu && (
                <p className="mt-1 text-[10px] text-glass-muted">
                  {t.defaultCpu} vCPU · {t.defaultMemoryGb} GB RAM
                </p>
              )}
              {onCreateFromTemplate && !readOnly && (
                <button
                  type="button"
                  className="btn-ghost mt-2 w-full text-xs"
                  onClick={() => {
                    const name = window.prompt(`VM name for template "${t.label}":`, `${t.id}-vm`)
                    if (name) onCreateFromTemplate(t.id, name)
                  }}
                >
                  Create from template (preview)
                </button>
              )}
            </div>
          ))}
        </div>
      </GlassCard>

      {vms && vms.vms.length > 0 && (
        <GlassCard>
          <h3 className="mb-2 font-medium">Running VMs</h3>
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-glass-muted">
                <th>Name</th>
                <th>Phase</th>
                <th>IP</th>
              </tr>
            </thead>
            <tbody>
              {vms.vms.map((vm) => (
                <tr key={`${vm.namespace}/${vm.name}`} className="border-t border-glass-border/40">
                  <td className="py-1">
                    {vm.namespace}/{vm.name}
                  </td>
                  <td>{vm.phase}</td>
                  <td>{vm.ip || '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </GlassCard>
      )}
    </div>
  )
}
