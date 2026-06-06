import { motion } from 'framer-motion'
import { GlassCard } from './GlassCard'

export function EmptyClusterWelcome({
  onCreate,
  onImport,
  onScan,
}: {
  onCreate: () => void
  onImport: () => void
  onScan: () => void
}) {
  return (
    <GlassCard className="empty-welcome mb-6 overflow-hidden border-glass-purple/20">
      <div className="relative">
        <div className="empty-welcome-glow" aria-hidden />
        <motion.div
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          className="relative z-10 flex flex-col items-center px-4 py-10 text-center"
        >
          <div className="mb-4 flex h-16 w-16 items-center justify-center rounded-2xl border border-glass-accent/30 bg-glass-accent/10 text-3xl shadow-zyvor-glow">
            ◈
          </div>
          <h3 className="text-gradient-brand text-xl font-semibold">Welcome to Hypercluster</h3>
          <p className="mt-2 max-w-md text-sm text-glass-muted">
            Deploy remote k3s platforms with Cilium, MetalLB, KubeVirt, and cert-manager — managed
            entirely through the hypercluster CLI from this app.
          </p>
          <div className="mt-6 flex flex-wrap justify-center gap-3">
            <button type="button" className="btn-primary" onClick={onCreate}>
              Create cluster
            </button>
            <button type="button" className="btn-ghost" onClick={onImport}>
              Import cluster.conf
            </button>
            <button type="button" className="btn-ghost" onClick={onScan}>
              Scan for configs
            </button>
          </div>
          <p className="mt-6 text-xs text-glass-muted">
            Tip: press <kbd className="kbd">⌘K</kbd> for commands · <kbd className="kbd">⌘J</kbd> for AI
          </p>
        </motion.div>
      </div>
    </GlassCard>
  )
}
