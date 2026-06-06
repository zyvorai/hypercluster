import { GlassCard } from './GlassCard'
import { ClusterLiveStats } from './ClusterLiveStats'
import type { ClusterLiveSummary } from '../lib/clusterLive'
import type { VmsJson, WorkloadsJson } from '../lib/types'

export function ClusterLiveSnapshot({
  summary,
  workloads,
  vms,
  loading,
  onGoWorkloads,
  onGoVms,
  onGoNodes,
}: {
  summary: ClusterLiveSummary | null
  workloads: WorkloadsJson | null
  vms: VmsJson | null
  loading?: boolean
  onGoWorkloads: () => void
  onGoVms: () => void
  onGoNodes: () => void
}) {
  const topPods = (workloads?.pods ?? [])
    .slice()
    .sort((a, b) => a.namespace.localeCompare(b.namespace) || a.name.localeCompare(b.name))
    .slice(0, 8)
  const topVms = (vms?.vms ?? []).slice(0, 6)

  return (
    <GlassCard>
      <div className="mb-4 flex flex-wrap items-center justify-between gap-2">
        <div>
          <h3 className="font-medium">Live cluster state</h3>
          <p className="text-xs text-glass-muted">From hypercluster status, workloads, and vms JSON</p>
        </div>
        <div className="flex flex-wrap gap-2">
          <button type="button" className="btn-ghost text-xs" onClick={onGoNodes}>
            Nodes
          </button>
          <button type="button" className="btn-ghost text-xs" onClick={onGoWorkloads}>
            All pods
          </button>
          <button type="button" className="btn-ghost text-xs" onClick={onGoVms}>
            VMs
          </button>
        </div>
      </div>

      <ClusterLiveStats summary={summary} loading={loading} />

      {topPods.length > 0 && (
        <div className="mt-5 border-t border-glass-border pt-4">
          <p className="mb-2 text-xs font-medium uppercase tracking-wider text-glass-muted">
            Recent pods
          </p>
          <div className="max-h-48 overflow-y-auto">
            <table className="w-full text-xs">
              <thead>
                <tr className="text-left text-glass-muted">
                  <th className="pb-1 pr-2">Namespace</th>
                  <th className="pb-1 pr-2">Pod</th>
                  <th className="pb-1">Phase</th>
                </tr>
              </thead>
              <tbody>
                {topPods.map((p) => (
                  <tr key={`${p.namespace}/${p.name}`} className="border-t border-glass-border/40">
                    <td className="py-1 pr-2 text-glass-muted">{p.namespace}</td>
                    <td className="max-w-[12rem] truncate py-1 pr-2">{p.name}</td>
                    <td
                      className={
                        p.phase === 'Running'
                          ? 'text-emerald-300'
                          : p.phase === 'Pending'
                            ? 'text-amber-200'
                            : 'text-red-300'
                      }
                    >
                      {p.phase}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {topVms.length > 0 && (
        <div className="mt-4 border-t border-glass-border pt-4">
          <p className="mb-2 text-xs font-medium uppercase tracking-wider text-glass-muted">
            Virtual machines
          </p>
          <ul className="space-y-1 text-sm">
            {topVms.map((vm) => (
              <li key={`${vm.namespace}/${vm.name}`} className="flex justify-between gap-2">
                <span className="truncate">
                  {vm.namespace}/{vm.name}
                </span>
                <span className={vm.phase === 'Running' ? 'text-emerald-300' : 'text-glass-muted'}>
                  {vm.phase}
                </span>
              </li>
            ))}
          </ul>
        </div>
      )}
    </GlassCard>
  )
}
