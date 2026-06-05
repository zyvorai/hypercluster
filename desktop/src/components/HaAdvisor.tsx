import type { ClusterSpec } from '../lib/types'
import { recommendHa } from '../lib/haAdvisor'
import { GlassCard } from './GlassCard'

export function HaAdvisor({
  spec,
  onApply,
}: {
  spec: ClusterSpec
  onApply?: (preset: ClusterSpec['haControlPlane']) => void
}) {
  const rec = recommendHa(spec)

  return (
    <GlassCard className="border-glass-accent/20 bg-glass-accent/5">
      <h4 className="mb-1 text-sm font-medium text-glass-accent">HA advisor</h4>
      <p className="mb-2 text-sm">{rec.summary}</p>
      {rec.vipHint && <p className="mb-2 text-xs text-glass-muted">{rec.vipHint}</p>}
      <ul className="mb-3 list-inside list-disc text-xs text-glass-muted">
        {rec.notes.map((n) => (
          <li key={n}>{n}</li>
        ))}
      </ul>
      {onApply && rec.preset !== 'custom' && (
        <button type="button" className="btn-ghost text-xs" onClick={() => onApply(rec.preset)}>
          Apply {rec.controlPlane} CP / {rec.workers} worker layout
        </button>
      )}
    </GlassCard>
  )
}
