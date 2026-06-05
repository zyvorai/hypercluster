import type { ClusterEntry } from '../lib/types'
import { GlassCard } from './GlassCard'

export function DeployOpsCenter({
  cluster,
  running,
  lastSuccess,
  onRun,
  onCancel,
}: {
  cluster: ClusterEntry
  running: boolean
  lastSuccess: boolean | null
  onRun: (command: string, opts?: { args?: string[]; force?: boolean; dryRun?: boolean }) => void
  onCancel: () => void
}) {
  return (
    <GlassCard className="mb-4 space-y-3">
      <h3 className="font-medium">Operations</h3>
      <div className="flex flex-wrap gap-2">
        {running ? (
          <button type="button" className="btn-ghost text-sm" onClick={onCancel}>
            Cancel job
          </button>
        ) : (
          <>
            <button type="button" className="btn-ghost text-sm" onClick={() => onRun('unlock')}>
              Unlock stale lock
            </button>
            <button
              type="button"
              className="btn-ghost text-sm"
              onClick={() => onRun('deploy', { dryRun: true })}
            >
              Dry-run deploy
            </button>
            <button type="button" className="btn-ghost text-sm" onClick={() => onRun('preflight')}>
              Re-run preflight
            </button>
            <button type="button" className="btn-ghost text-sm" onClick={() => onRun('fetch-kubeconfig')}>
              Fetch kubeconfig
            </button>
            <button type="button" className="btn-ghost text-sm" onClick={() => onRun('upgrade')}>
              Upgrade cluster
            </button>
            <button type="button" className="btn-ghost text-sm" onClick={() => onRun('scale')}>
              Scale (add nodes)
            </button>
          </>
        )}
      </div>
      {!running && lastSuccess === false && (
        <div className="rounded-lg border border-amber-500/30 bg-amber-500/10 p-3 text-sm">
          <p className="font-medium text-amber-200">Rollback options</p>
          <p className="mt-1 text-xs text-glass-muted">
            Full automated rollback is not yet available. You can unlock a stale lock, re-run deploy
            after fixing config, or use destroy for teardown.
          </p>
          <div className="mt-2 flex flex-wrap gap-2">
            <button type="button" className="btn-ghost text-xs" onClick={() => onRun('unlock')}>
              Rollback: unlock
            </button>
            <button type="button" className="btn-ghost text-xs" onClick={() => onRun('deploy')}>
              Rollback: retry deploy
            </button>
          </div>
        </div>
      )}
      <p className="text-xs text-glass-muted">Cluster: {cluster.name}</p>
    </GlassCard>
  )
}
