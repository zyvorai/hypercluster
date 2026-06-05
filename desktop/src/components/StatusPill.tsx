export function StatusPill({
  status,
}: {
  status: 'ready' | 'running' | 'deploying' | 'error' | 'unknown' | string
}) {
  const colors: Record<string, string> = {
    ready: 'bg-emerald-500/20 text-emerald-300 border-emerald-500/30',
    running: 'bg-amber-500/20 text-amber-200 border-amber-500/30',
    deploying: 'bg-amber-500/20 text-amber-200 border-amber-500/30',
    error: 'bg-red-500/20 text-red-300 border-red-500/30',
    unknown: 'bg-white/10 text-glass-muted border-glass-border',
  }
  const c = colors[status] ?? colors.unknown
  const label = status === 'running' ? 'running' : status
  return (
    <span className={`inline-flex rounded-full border px-2.5 py-0.5 text-xs font-medium ${c}`}>
      {label}
    </span>
  )
}
