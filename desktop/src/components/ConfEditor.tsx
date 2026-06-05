import { useEffect } from 'react'
import Editor from '@monaco-editor/react'
import { GlassCard } from './GlassCard'

export function ConfEditor({
  value,
  onChange,
  onSave,
  onCancel,
  saving,
  path,
}: {
  value: string
  onChange: (v: string) => void
  onSave: () => void
  onCancel: () => void
  saving?: boolean
  path: string
}) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 's') {
        e.preventDefault()
        if (!saving) onSave()
      }
      if (e.key === 'Escape') onCancel()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onSave, onCancel, saving])

  return (
    <GlassCard className="flex h-[calc(100vh-8rem)] flex-col">
      <div className="mb-3 flex items-center justify-between gap-2">
        <div>
          <h2 className="text-lg font-semibold">Edit cluster.conf</h2>
          <p className="truncate text-xs text-glass-muted">{path}</p>
          <p className="text-[10px] text-glass-muted">⌘S save · Esc cancel</p>
        </div>
        <div className="flex gap-2">
          <button type="button" className="btn-ghost" onClick={onCancel} disabled={saving}>
            Cancel
          </button>
          <button type="button" className="btn-primary" onClick={onSave} disabled={saving}>
            {saving ? 'Saving…' : 'Save'}
          </button>
        </div>
      </div>
      <div className="min-h-0 flex-1 overflow-hidden rounded-xl border border-glass-border">
        <Editor
          height="100%"
          defaultLanguage="shell"
          theme="vs-dark"
          value={value}
          onChange={(v) => onChange(v ?? '')}
          options={{
            minimap: { enabled: false },
            fontSize: 13,
            wordWrap: 'on',
            scrollBeyondLastLine: false,
          }}
        />
      </div>
    </GlassCard>
  )
}
