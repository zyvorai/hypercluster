/** Minimal markdown-ish rendering for copilot replies (no external deps). */
export function AiMarkdown({ text }: { text: string }) {
  const lines = text.split('\n')
  const nodes: React.ReactNode[] = []
  let inCode = false
  let codeBuf: string[] = []

  const flushCode = (key: number) => {
    if (!codeBuf.length) return
    nodes.push(
      <pre
        key={`code-${key}`}
        className="overflow-x-auto rounded-lg bg-black/40 px-3 py-2 text-xs text-emerald-100/90"
      >
        {codeBuf.join('\n')}
      </pre>,
    )
    codeBuf = []
  }

  lines.forEach((line, i) => {
    if (line.trim().startsWith('```')) {
      if (inCode) {
        flushCode(i)
        inCode = false
      } else {
        inCode = true
      }
      return
    }
    if (inCode) {
      codeBuf.push(line)
      return
    }
    const trimmed = line.trim()
    if (!trimmed) {
      nodes.push(<div key={i} className="h-1" />)
      return
    }
    if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
      nodes.push(
        <p key={i} className="pl-3 text-white/90">
          <span className="text-glass-purple">•</span> {renderInline(trimmed.slice(2))}
        </p>,
      )
      return
    }
    if (/^#{1,3}\s/.test(trimmed)) {
      const level = trimmed.match(/^#+/)?.[0].length ?? 1
      const content = trimmed.replace(/^#+\s*/, '')
      nodes.push(
        <p
          key={i}
          className={
            level <= 2 ? 'text-sm font-semibold text-glass-accent-light' : 'font-medium text-white'
          }
        >
          {renderInline(content)}
        </p>,
      )
      return
    }
    nodes.push(
      <p key={i} className="text-white/90">
        {renderInline(trimmed)}
      </p>,
    )
  })
  flushCode(lines.length)

  return <div className="space-y-1.5 leading-relaxed">{nodes}</div>
}

function renderInline(text: string) {
  const parts = text.split(/(`[^`]+`)/g)
  if (parts.length === 1) return text
  return parts.map((part, i) =>
    part.startsWith('`') && part.endsWith('`') ? (
      <code key={i} className="rounded bg-black/30 px-1 py-0.5 text-xs text-emerald-200">
        {part.slice(1, -1)}
      </code>
    ) : (
      <span key={i}>{part}</span>
    ),
  )
}
