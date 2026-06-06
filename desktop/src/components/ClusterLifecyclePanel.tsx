import { useState } from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import type { ClusterEntry } from '../lib/types'
import { GlassCard } from './GlassCard'

export function ClusterLifecyclePanel({
  cluster,
  provisioned,
  disabled,
  onDecommission,
  onReinstall,
  onFullDeploy,
}: {
  cluster: ClusterEntry
  provisioned?: boolean
  disabled?: boolean
  onDecommission: () => void
  onReinstall: () => void
  onFullDeploy: () => void
}) {
  const [confirm, setConfirm] = useState('')
  const [mode, setMode] = useState<'idle' | 'decommission' | 'reinstall'>('idle')

  const reset = () => {
    setConfirm('')
    setMode('idle')
  }

  const steps = [
    { label: 'Config', done: true },
    { label: 'Deploy', done: provisioned },
    { label: 'Live', done: provisioned },
  ]

  return (
    <GlassCard className="space-y-4 border-glass-accent/20">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <h3 className="font-medium">Cluster lifecycle</h3>
          <p className="text-xs text-glass-muted">
            {provisioned
              ? 'Live cluster detected — decommission or reinstall from here.'
              : 'No live cluster yet — deploy to provision.'}
          </p>
        </div>
        {provisioned ? (
          <span className="inline-flex items-center gap-1.5 rounded-full bg-emerald-500/15 px-2 py-0.5 text-xs text-emerald-300">
            <span className="pulse-dot pulse-dot-emerald" />
            Provisioned
          </span>
        ) : (
          <span className="rounded-full bg-white/10 px-2 py-0.5 text-xs text-glass-muted">
            Not provisioned
          </span>
        )}
      </div>

      <div className="flex items-center gap-2">
        {steps.map((s, i) => (
          <div key={s.label} className="flex flex-1 items-center gap-2">
            <div
              className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-xs font-medium ${
                s.done
                  ? 'bg-emerald-500/20 text-emerald-200 ring-1 ring-emerald-500/30'
                  : 'bg-white/5 text-glass-muted ring-1 ring-glass-border'
              }`}
            >
              {s.done ? '✓' : i + 1}
            </div>
            <span className={`text-xs ${s.done ? 'text-white' : 'text-glass-muted'}`}>{s.label}</span>
            {i < steps.length - 1 && (
              <div className={`h-px flex-1 ${s.done ? 'bg-emerald-500/30' : 'bg-glass-border'}`} />
            )}
          </div>
        ))}
      </div>

      <div className="flex flex-wrap gap-2">
        <button type="button" className="btn-primary text-sm" disabled={disabled} onClick={onFullDeploy}>
          {provisioned ? 'Redeploy stack' : 'Deploy full stack'}
        </button>
        {provisioned && (
          <>
            <button
              type="button"
              className="btn-ghost text-sm"
              disabled={disabled}
              onClick={() => setMode(mode === 'decommission' ? 'idle' : 'decommission')}
            >
              Decommission
            </button>
            <button
              type="button"
              className="btn-ghost text-sm"
              disabled={disabled}
              onClick={() => setMode(mode === 'reinstall' ? 'idle' : 'reinstall')}
            >
              Reinstall (destroy + deploy)
            </button>
          </>
        )}
      </div>

      <AnimatePresence>
        {mode !== 'idle' && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            exit={{ opacity: 0, height: 0 }}
            className="overflow-hidden"
          >
            <div className="rounded-xl border border-red-500/30 bg-red-500/10 p-3">
              <p className="mb-2 text-sm text-red-100">
                {mode === 'decommission'
                  ? `Decommission runs hypercluster destroy on ${cluster.name} — removes k3s/Kubespray from remote hosts.`
                  : `Reinstall destroys ${cluster.name} then runs preflight → deploy → test. All workloads will be wiped.`}
              </p>
              <input
                className="input-glass mb-2"
                placeholder={`Type ${cluster.name} to confirm`}
                value={confirm}
                onChange={(e) => setConfirm(e.target.value)}
              />
              <div className="flex gap-2">
                <button type="button" className="btn-ghost text-sm" onClick={reset}>
                  Cancel
                </button>
                <button
                  type="button"
                  className="rounded-full bg-red-600/90 px-4 py-2 text-sm font-medium text-white disabled:opacity-40"
                  disabled={disabled || confirm !== cluster.name}
                  onClick={() => {
                    if (confirm !== cluster.name) return
                    if (mode === 'decommission') onDecommission()
                    else onReinstall()
                    reset()
                  }}
                >
                  {mode === 'decommission' ? 'Confirm decommission' : 'Confirm reinstall'}
                </button>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </GlassCard>
  )
}
