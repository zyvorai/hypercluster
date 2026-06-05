import { STUDIO_INTENTS } from '../lib/studioIntents'
import { STUDIO_TEMPLATES } from '../lib/templates'
import type { ClusterEntry, StudioIntentId } from '../lib/types'
import { GlassCard } from './GlassCard'

export function CreateClusterHub({
  clusters,
  onIntent,
  onImport,
  onClone,
  onAdvancedStudio,
  onBack,
}: {
  clusters: ClusterEntry[]
  onIntent: (intentId: StudioIntentId, mode: 'quick' | 'advanced') => void
  onImport: () => void
  onClone: (cluster: ClusterEntry) => void
  onAdvancedStudio: () => void
  onBack: () => void
}) {
  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-semibold tracking-tight">Create Cluster</h2>
          <p className="mt-1 text-glass-muted">
            Describe what you want — Hypercluster generates inventory, Helm values, and topology.
          </p>
        </div>
        <button type="button" className="btn-ghost text-sm" onClick={onBack}>
          ← Back
        </button>
      </div>

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        {STUDIO_INTENTS.map((intent) => (
          <GlassCard
            key={intent.id}
            className="group cursor-pointer transition hover:border-glass-accent/40 hover:bg-white/5"
            onClick={() => onIntent(intent.id, 'quick')}
          >
            <div className="mb-3 text-4xl">{intent.icon}</div>
            <h3 className="text-xl font-semibold">{intent.label}</h3>
            <p className="text-sm text-glass-accent">{intent.tagline}</p>
            <p className="mt-2 text-sm text-glass-muted">{intent.description}</p>
            <div className="mt-4 flex flex-wrap gap-1">
              {intent.stackPreview.map((s) => (
                <span key={s} className="rounded-lg bg-black/20 px-2 py-0.5 text-xs">
                  {s}
                </span>
              ))}
            </div>
            <div className="mt-4 flex gap-2 opacity-80 group-hover:opacity-100">
              <button
                type="button"
                className="btn-primary text-sm"
                onClick={(e) => {
                  e.stopPropagation()
                  onIntent(intent.id, 'quick')
                }}
              >
                Quick Deploy
              </button>
              <button
                type="button"
                className="btn-ghost text-sm"
                onClick={(e) => {
                  e.stopPropagation()
                  onIntent(intent.id, 'advanced')
                }}
              >
                Customize
              </button>
            </div>
          </GlassCard>
        ))}

        <GlassCard
          className="cursor-pointer border-dashed hover:bg-white/5"
          onClick={onImport}
        >
          <div className="mb-3 text-4xl">📥</div>
          <h3 className="text-xl font-semibold">Import</h3>
          <p className="text-sm text-glass-accent">Existing cluster.conf</p>
          <p className="mt-2 text-sm text-glass-muted">
            Bring a config from disk into the desktop registry.
          </p>
        </GlassCard>
      </div>

      <GlassCard>
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h3 className="font-medium">Expert mode</h3>
            <p className="text-sm text-glass-muted">
              Full Kubespray control — 445+ searchable settings, distro matrix, Cilium studio.
            </p>
          </div>
          <button type="button" className="btn-ghost" onClick={onAdvancedStudio}>
            Open Advanced Studio
          </button>
        </div>
      </GlassCard>

      {clusters.length > 0 && (
        <GlassCard>
          <h3 className="mb-3 font-medium">Clone cluster</h3>
          <div className="flex flex-wrap gap-2">
            {clusters.map((c) => (
              <button key={c.id} type="button" className="btn-ghost text-sm" onClick={() => onClone(c)}>
                {c.name}
              </button>
            ))}
          </div>
        </GlassCard>
      )}

      <div>
        <h3 className="mb-3 font-medium text-glass-muted">Template catalog</h3>
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {STUDIO_TEMPLATES.map((t) => (
            <GlassCard
              key={t.id}
              className="cursor-pointer hover:bg-white/5"
              onClick={() => onIntent(
                t.id === 'gpu-cluster' ? 'ai-platform'
                  : t.id === 'kubevirt-lab' ? 'virtualization'
                  : t.id === 'edge-cluster' ? 'edge'
                  : 'kubernetes',
                'advanced',
              )}
            >
              <p className="text-xs text-glass-accent">{t.intent}</p>
              <h4 className="font-medium">{t.label}</h4>
              <p className="mt-1 text-sm text-glass-muted">{t.description}</p>
            </GlassCard>
          ))}
        </div>
      </div>
    </div>
  )
}
