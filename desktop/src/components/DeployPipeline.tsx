import { motion } from 'framer-motion'
import type { ParsedStage } from '../lib/types'
import { GlassCard } from './GlassCard'

const PIPELINE = [
  { id: 'infra', label: 'Infrastructure', icon: '◈', match: /preflight|init|host prep|inventory/i },
  { id: 'k8s', label: 'Kubernetes', icon: '◆', match: /k3s|kubespray|cluster\.yml|rke2|microk8s|install|server|agent/i },
  { id: 'platform', label: 'Platform', icon: '✦', match: /platform|helm|cilium|metallb|kubevirt|cdi|stack/i },
  { id: 'validation', label: 'Validation', icon: '✓', match: /kubeconfig|tools|merge|done|fetch|test/i },
]

function stagePhase(label: string, current: number, total: number): string {
  for (const p of PIPELINE) {
    if (p.match.test(label)) return p.id
  }
  if (current <= 1) return 'infra'
  if (current >= total) return 'validation'
  if (current <= Math.ceil(total / 2)) return 'k8s'
  return 'platform'
}

export function DeployPipeline({
  stage,
  running,
}: {
  stage: ParsedStage | null
  running: boolean
}) {
  const activePhase = stage ? stagePhase(stage.label, stage.current, stage.total) : null
  const activeIdx = PIPELINE.findIndex((p) => p.id === activePhase)
  const progress = stage ? Math.round((stage.current / stage.total) * 100) : running ? 4 : 0

  return (
    <GlassCard className="mb-4 space-y-4 border-glass-accent/15">
      <div className="flex items-center justify-between">
        <div>
          <h3 className="font-medium">Deploy pipeline</h3>
          <p className="text-xs text-glass-muted">preflight → k3s → platform stack → validation</p>
        </div>
        {stage ? (
          <span className="rounded-full bg-glass-accent/15 px-2.5 py-1 text-xs text-glass-accent-light">
            Stage {stage.current}/{stage.total}
          </span>
        ) : running ? (
          <span className="inline-flex items-center gap-2 text-xs text-glass-muted">
            <span className="spinner" /> Starting…
          </span>
        ) : null}
      </div>

      <div className="grid grid-cols-4 gap-2">
        {PIPELINE.map((p, i) => {
          const active = activePhase === p.id
          const done = stage && activeIdx > i
          return (
            <motion.div
              key={p.id}
              animate={active ? { scale: [1, 1.02, 1] } : { scale: 1 }}
              transition={active ? { duration: 1.6, repeat: Infinity } : undefined}
              className={`deploy-phase rounded-xl border px-2 py-3 text-center text-xs ${
                active
                  ? 'deploy-phase-active'
                  : done
                    ? 'border-emerald-500/40 bg-emerald-500/10 text-emerald-200'
                    : 'border-glass-border bg-black/10 text-glass-muted'
              }`}
            >
              <div className="mb-1 text-base opacity-80">{done ? '✓' : p.icon}</div>
              {p.label}
            </motion.div>
          )
        })}
      </div>

      {(stage || running) && (
        <>
          {stage && <p className="text-sm font-medium">{stage.label}</p>}
          <div className="stat-bar h-2.5">
            <motion.div
              className="stat-bar-fill h-full"
              initial={{ width: 0 }}
              animate={{ width: `${progress}%` }}
              transition={{ duration: 0.4, ease: 'easeOut' }}
            />
          </div>
          <p className="text-right text-[10px] text-glass-muted">{progress}%</p>
        </>
      )}
    </GlassCard>
  )
}

export function DeployJobHeader({
  clusterName,
  command,
  running,
  success,
  onBack,
  backLabel = 'Back',
}: {
  clusterName: string
  command: string
  running: boolean
  success: boolean | null
  onBack?: () => void
  backLabel?: string
}) {
  return (
    <div className="cockpit-header mb-4 flex flex-wrap items-center justify-between gap-3 p-5">
      <div>
        <p className="mb-1 text-xs uppercase tracking-wider text-glass-muted">Job console</p>
        <h2 className="text-gradient-brand text-xl font-bold">
          {clusterName} — {command}
        </h2>
        <div className="mt-2 flex flex-wrap items-center gap-2 text-sm">
          {running && (
            <span className="inline-flex items-center gap-2 text-amber-200">
              <span className="pulse-dot pulse-dot-amber" /> Running
            </span>
          )}
          {!running && success === true && (
            <span className="text-emerald-300">✓ Succeeded</span>
          )}
          {!running && success === false && (
            <span className="text-red-300">✗ Failed</span>
          )}
        </div>
      </div>
      {onBack && (
        <button type="button" className="btn-primary text-sm" onClick={onBack}>
          {backLabel}
        </button>
      )}
    </div>
  )
}
