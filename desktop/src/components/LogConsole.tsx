import { useEffect, useRef } from 'react'

export function LogConsole({ lines }: { lines: string[] }) {
  const ref = useRef<HTMLDivElement>(null)
  useEffect(() => {
    ref.current?.scrollTo({ top: ref.current.scrollHeight })
  }, [lines])
  return (
    <div
      ref={ref}
      className="glass-panel h-80 overflow-y-auto p-3 font-mono text-xs leading-relaxed text-white/85"
    >
      {lines.length === 0 ? (
        <p className="text-glass-muted">Waiting for output…</p>
      ) : (
        lines.map((line, i) => (
          <div key={`${i}-${line.slice(0, 24)}`} className="whitespace-pre-wrap break-all">
            {line}
          </div>
        ))
      )}
    </div>
  )
}
