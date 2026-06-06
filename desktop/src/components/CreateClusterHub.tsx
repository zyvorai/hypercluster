import { motion } from 'framer-motion'
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
      <div className="hero-panel flex flex-wrap items-end justify-between gap-4 p-6">
        <motion.div initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }}>
          <p className="mb-1 text-xs font-medium uppercase tracking-[0.25em] text-glass-accent-light">
            Cluster Studio
          </p>
          <h2 className="text-gradient-brand text-3xl font-bold tracking-tight">Create cluster</h2>
          <p className="mt-2 max-w-xl text-sm text-glass-muted">
            Describe what you want — Hypercluster generates inventory, Helm values, and topology.
          </p>
        </motion.div>
        <button type="button" className="btn-ghost text-sm" onClick={onBack}>
          ← Dashboard
        </button>
      </div>

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        {STUDIO_INTENTS.map((intent, i) => (
          <motion.div
            key={intent.id}
            initial={{ opacity: 0, y: 14 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.05 }}
          >
            <GlassCard
              interactive
              className="studio-intent-card group cursor-pointer border-glass-border hover:border-glass-accent/35"
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
              <div className="mt-4 flex gap-2 opacity-90 group-hover:opacity-100">
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
          </motion.div>
        ))}

        <motion.div
          initial={{ opacity: 0, y: 14 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: STUDIO_INTENTS.length * 0.05 }}
        >
          <GlassCard
            interactive
            className="studio-intent-card h-full cursor-pointer border-dashed border-glass-purple/30 hover:border-glass-purple/50"
            onClick={onImport}
          >
            <div className="mb-3 text-4xl">📥</div>
            <h3 className="text-xl font-semibold">Import</h3>
            <p className="text-sm text-glass-accent">Existing cluster.conf</p>
            <p className="mt-2 text-sm text-glass-muted">
              Bring a config from disk into the desktop registry.
            </p>
          </GlassCard>
        </motion.div>
      </div>

      <GlassCard className="border-glass-purple/20">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h3 className="font-medium">Expert mode</h3>
            <p className="text-sm text-glass-muted">
              Full Kubespray control — 445+ searchable settings, distro matrix, Cilium studio.
            </p>
          </div>
          <button type="button" className="btn-primary" onClick={onAdvancedStudio}>
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
        <h3 className="mb-3 text-sm font-medium uppercase tracking-wider text-glass-muted">
          Template catalog
        </h3>
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {STUDIO_TEMPLATES.map((t, i) => (
            <motion.div
              key={t.id}
              initial={{ opacity: 0, scale: 0.98 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ delay: 0.03 * i }}
            >
              <GlassCard
                interactive
                className="cursor-pointer hover:border-glass-accent/25"
                onClick={() =>
                  onIntent(
                    t.id === 'gpu-cluster'
                      ? 'ai-platform'
                      : t.id === 'kubevirt-lab'
                        ? 'virtualization'
                        : t.id === 'edge-cluster'
                          ? 'edge'
                          : 'kubernetes',
                    'advanced',
                  )
                }
              >
                <p className="text-xs text-glass-accent">{t.intent}</p>
                <h4 className="font-medium">{t.label}</h4>
                <p className="mt-1 text-sm text-glass-muted">{t.description}</p>
              </GlassCard>
            </motion.div>
          ))}
        </div>
      </div>
    </div>
  )
}
