import { useEffect, useRef, useMemo, useState } from 'react'
import type { LogFilter } from '../lib/types'

function classifyLine(line: string): LogFilter {
  if (/error|failed|fatal|❌|die:/i.test(line)) return 'errors'
  if (/warn|warning|⚠/i.test(line)) return 'warnings'
  if (/stage|preflight|install|deploy|progress|✓|ok |done/i.test(line)) return 'progress'
  return 'all'
}

export function StructuredLogConsole({ lines }: { lines: string[] }) {
  const ref = useRef<HTMLDivElement>(null)
  const [filter, setFilter] = useState<LogFilter>('all')

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
    ref.current?.scrollTo({ top: ref.current.scrollHeight })
  }, [lines, filter])

  const color = (kind: LogFilter) => {
    if (kind === 'errors') return 'text-red-300'
    if (kind === 'warnings') return 'text-amber-200'
    if (kind === 'progress') return 'text-emerald-200/90'
    return 'text-white/85'
  }

  return (
    <div>
      <div className="mb-2 flex flex-wrap gap-2">
        {(
          [
            ['all', `All (${lines.length})`],
            ['errors', `Errors (${counts.errors})`],
            ['warnings', `Warnings (${counts.warnings})`],
            ['progress', `Progress (${counts.progress})`],
          ] as const
        ).map(([id, label]) => (
          <button
            key={id}
            type="button"
            className={`rounded-lg px-2 py-1 text-xs ${
              filter === id ? 'bg-glass-accent/30' : 'bg-white/5 text-glass-muted'
            }`}
            onClick={() => setFilter(id)}
          >
            {label}
          </button>
        ))}
      </div>
      <div
        ref={ref}
        className="glass-panel h-80 overflow-y-auto p-3 font-mono text-xs leading-relaxed"
      >
        {filtered.length === 0 ? (
          <p className="text-glass-muted">No lines match this filter.</p>
        ) : (
          filtered.map(({ line, i, kind }) => (
            <div key={`${i}-${line.slice(0, 20)}`} className={`whitespace-pre-wrap break-all ${color(kind)}`}>
              {line}
            </div>
          ))
        )}
      </div>
    </div>
  )
}
