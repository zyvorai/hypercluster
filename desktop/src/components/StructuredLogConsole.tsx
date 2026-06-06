import { useEffect, useRef, useMemo, useState } from 'react'
import type { LogFilter } from '../lib/types'

function classifyLine(line: string): LogFilter {
  if (/error|failed|fatal|❌|die:/i.test(line)) return 'errors'
  if (/warn|warning|⚠/i.test(line)) return 'warnings'
  if (/stage|preflight|install|deploy|progress|✓|ok |done/i.test(line)) return 'progress'
  return 'all'
}

const FILTERS: { id: LogFilter; label: string }[] = [
  { id: 'all', label: 'All' },
  { id: 'errors', label: 'Errors' },
  { id: 'warnings', label: 'Warnings' },
  { id: 'progress', label: 'Progress' },
]

export function StructuredLogConsole({ lines }: { lines: string[] }) {
  const ref = useRef<HTMLDivElement>(null)
  const [filter, setFilter] = useState<LogFilter>('all')
  const [autoScroll, setAutoScroll] = useState(true)

  const classified = useMemo(
    () =>
      lines.map((line, i) => ({
        line,
        i,
        kind: classifyLine(line),
      })),
    [lines],
  )

  const filtered = useMemo(() => {
    if (filter === 'all') return classified
    return classified.filter((c) => c.kind === filter)
  }, [classified, filter])

  const counts = useMemo(() => {
    const c = { errors: 0, warnings: 0, progress: 0 }
    for (const x of classified) {
      if (x.kind === 'errors') c.errors++
      else if (x.kind === 'warnings') c.warnings++
      else if (x.kind === 'progress') c.progress++
    }
    return c
  }, [classified])

  useEffect(() => {
    if (autoScroll) ref.current?.scrollTo({ top: ref.current.scrollHeight, behavior: 'smooth' })
  }, [lines, filter, autoScroll])

  const color = (kind: LogFilter) => {
    if (kind === 'errors') return 'text-red-300'
    if (kind === 'warnings') return 'text-amber-200'
    if (kind === 'progress') return 'text-emerald-200/90'
    return 'text-white/85'
  }

  const countFor = (id: LogFilter) => {
    if (id === 'all') return lines.length
    if (id === 'errors') return counts.errors
    if (id === 'warnings') return counts.warnings
    return counts.progress
  }

  return (
    <div>
      <div className="mb-2 flex flex-wrap items-center justify-between gap-2">
        <div className="flex flex-wrap gap-1.5">
          {FILTERS.map(({ id, label }) => (
            <button
              key={id}
              type="button"
              className={`cockpit-tab text-xs ${filter === id ? 'cockpit-tab-active' : ''}`}
              onClick={() => setFilter(id)}
            >
              {label} ({countFor(id)})
            </button>
          ))}
        </div>
        <button
          type="button"
          className={`text-[10px] uppercase tracking-wider ${autoScroll ? 'text-glass-accent-light' : 'text-glass-muted'}`}
          onClick={() => setAutoScroll((v) => !v)}
        >
          Auto-scroll {autoScroll ? 'on' : 'off'}
        </button>
      </div>
      <div ref={ref} className="log-console-panel glass-panel h-80 overflow-y-auto p-3 font-mono text-xs leading-relaxed">
        {filtered.length === 0 ? (
          <p className="text-glass-muted">
            {lines.length === 0 ? 'Waiting for job output…' : 'No lines match this filter.'}
          </p>
        ) : (
          filtered.map(({ line, i, kind }) => (
            <div
              key={`${i}-${line.slice(0, 24)}`}
              className={`log-line whitespace-pre-wrap break-all ${color(kind)}`}
            >
              {line}
            </div>
          ))
        )}
      </div>
    </div>
  )
}
