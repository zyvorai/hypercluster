import type { ParsedStage } from '../lib/types'
import { GlassCard } from './GlassCard'

const PIPELINE = [
  { id: 'infra', label: 'Infrastructure', match: /preflight|init|host prep|inventory/i },
  { id: 'k8s', label: 'Kubernetes', match: /k3s|kubespray|cluster\.yml|rke2|microk8s|install|server|agent/i },
  { id: 'platform', label: 'Platform', match: /platform|helm|cilium|metallb|kubevirt|cdi|stack/i },
  { id: 'validation', label: 'Validation', match: /kubeconfig|tools|merge|done|fetch/i },
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
  const progress = stage ? Math.round((stage.current / stage.total) * 100) : 0

  return (
    <GlassCard className="mb-4 space-y-4">
      <div className="flex items-center justify-between">
        <h3 className="font-medium">Deploy pipeline</h3>
        {stage && (
          <span className="text-sm text-glass-muted">
            Stage {stage.current}/{stage.total}
          </span>
        )}
      </div>
      <div className="grid grid-cols-4 gap-2">
        {PIPELINE.map((p) => {
          const active = activePhase === p.id
          const done =
            stage &&
            PIPELINE.findIndex((x) => x.id === p.id) <
              PIPELINE.findIndex((x) => x.id === activePhase)
          return (
            <div
              key={p.id}
              className={`rounded-xl border px-2 py-3 text-center text-xs ${
                active
                  ? 'border-glass-accent bg-glass-accent/20 text-white'
                  : done
                    ? 'border-emerald-500/40 bg-emerald-500/10 text-emerald-200'
                    : 'border-glass-border bg-black/10 text-glass-muted'
              }`}
            >
              {p.label}
            </div>
          )
        })}
      </div>
      {stage && (
        <>
          <p className="text-sm font-medium">{stage.label}</p>
          <div className="h-2 overflow-hidden rounded-full bg-black/30">
            <div
              className="h-full bg-glass-accent transition-all duration-300"
              style={{ width: `${progress}%` }}
            />
          </div>
        </>
      )}
      {!stage && running && <p className="text-sm text-glass-muted">Starting…</p>}
    </GlassCard>
  )
}
