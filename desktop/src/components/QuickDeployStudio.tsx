import { useState } from 'react'
import type { ClusterSpec, StudioIntentId } from '../lib/types'
import { buildClusterConfFromSpec } from '../lib/api'
import { intentById } from '../lib/studioIntents'
import { estimateInstallMinutes, installPlan } from '../lib/clusterSpec'
import { GlassCard } from './GlassCard'
import { LivePreviewPanel } from './LivePreviewPanel'
import { NodeCanvas } from './NodeCanvas'

const STEPS = ['Name', 'Infrastructure', 'Deploy'] as const

export function QuickDeployStudio({
  spec,
  intentId,
  onChange,
  onSave,
  onDeploy,
  onBack,
  onAdvanced,
  saving,
}: {
  spec: ClusterSpec
  intentId: StudioIntentId
  onChange: (spec: ClusterSpec) => void
  onSave: () => void
  onDeploy: () => void
  onBack: () => void
  onAdvanced: () => void
  saving?: boolean
}) {
  const [step, setStep] = useState(0)
  const intent = intentById(intentId)
  const mins = estimateInstallMinutes(spec)

  return (
    <div className="flex gap-6">
      <div className="min-w-0 flex-1 space-y-4">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div>
            <button type="button" className="btn-ghost mb-1 text-sm" onClick={onBack}>
              ← Back
            </button>
            <h2 className="text-xl font-semibold">Quick Deploy</h2>
            <p className="text-sm text-glass-muted">
              {intent.icon} {intent.label} · target &lt; {mins} min
            </p>
          </div>
          <button type="button" className="text-xs text-glass-accent" onClick={onAdvanced}>
            Advanced Studio →
          </button>
        </div>

        <div className="flex gap-2">
          {STEPS.map((label, i) => (
            <span
              key={label}
              className={`rounded-lg px-3 py-1 text-sm ${
                step === i ? 'bg-glass-accent/30' : 'bg-white/5 text-glass-muted'
              }`}
            >
              {i + 1}. {label}
            </span>
          ))}
        </div>

        {step === 0 && (
          <GlassCard className="space-y-4">
            <h3 className="font-medium">Cluster name</h3>
            <input
              autoFocus
              className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2 text-lg"
              value={spec.clusterName}
              onChange={(e) => onChange({ ...spec, clusterName: e.target.value })}
              placeholder="my-cluster"
            />
            <p className="text-sm text-glass-muted">{intent.description}</p>
            <div className="flex flex-wrap gap-1">
              {intent.stackPreview.map((s) => (
                <span key={s} className="rounded bg-white/5 px-2 py-0.5 text-xs">
                  {s}
                </span>
              ))}
            </div>
          </GlassCard>
        )}

        {step === 1 && <NodeCanvas spec={spec} onChange={onChange} />}

        {step === 2 && (
          <GlassCard className="space-y-3">
            <h3 className="font-medium">Ready to deploy</h3>
            <p className="text-sm text-glass-muted">
              Hypercluster generates inventory, Helm values, and SSH topology from your spec — no
              manual cluster.conf editing.
            </p>
            <ul className="text-sm">
              {installPlan(spec).map((item) => (
                <li key={item}>✓ {item}</li>
              ))}
            </ul>
            <details>
              <summary className="cursor-pointer text-xs text-glass-muted">Generated config preview</summary>
              <pre className="mt-2 max-h-40 overflow-auto rounded bg-black/30 p-2 text-xs">
                {buildClusterConfFromSpec(spec)}
              </pre>
            </details>
          </GlassCard>
        )}

        <div className="flex justify-between">
          <button
            type="button"
            className="btn-ghost"
            disabled={step === 0}
            onClick={() => setStep((s) => s - 1)}
          >
            Back
          </button>
          {step < STEPS.length - 1 ? (
            <button
              type="button"
              className="btn-primary"
              disabled={step === 0 && !spec.clusterName.trim()}
              onClick={() => setStep((s) => s + 1)}
            >
              Next
            </button>
          ) : (
            <div className="flex gap-2">
              <button type="button" className="btn-ghost" disabled={saving} onClick={onSave}>
                Save only
              </button>
              <button type="button" className="btn-primary" disabled={saving} onClick={onDeploy}>
                Deploy now
              </button>
            </div>
          )}
        </div>
      </div>
      <div className="hidden w-72 shrink-0 lg:block">
        <LivePreviewPanel spec={spec} />
      </div>
    </div>
  )
}
