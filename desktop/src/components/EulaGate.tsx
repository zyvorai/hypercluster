import { useEffect, useState } from 'react'
import { ZyvorLogoMark } from './ZyvorBrand'
import { invoke } from '@tauri-apps/api/core'
import { getCurrentWindow } from '@tauri-apps/api/window'

export function EulaGate({ children }: { children: React.ReactNode }) {
  const [loading, setLoading] = useState(true)
  const [accepted, setAccepted] = useState(false)
  const [unsupportedArch, setUnsupportedArch] = useState(false)
  const [hostArch, setHostArch] = useState('')
  const [summary, setSummary] = useState('')
  const [error, setError] = useState('')

  useEffect(() => {
    let cancelled = false
    ;(async () => {
      try {
        const arch = await invoke<string>('host_cpu_arch_cmd')
        const needsArm = await invoke<boolean>('macos_arm64_required_cmd')
        if (cancelled) return
        setHostArch(arch)
        if (needsArm) {
          setUnsupportedArch(true)
          return
        }
        const ok = await invoke<boolean>('license_is_accepted_cmd')
        if (cancelled) return
        if (ok) {
          setAccepted(true)
          return
        }
        const text = await invoke<string>('license_summary_cmd')
        if (!cancelled) setSummary(text)
      } catch (e) {
        if (!cancelled) setError(String(e))
      } finally {
        if (!cancelled) setLoading(false)
      }
    })()
    return () => {
      cancelled = true
    }
  }, [])

  const accept = async () => {
    setError('')
    try {
      await invoke('license_accept_cmd', { actor: null })
      setAccepted(true)
    } catch (e) {
      setError(String(e))
    }
  }

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[#0B0B0F] text-glass-muted">
        Loading…
      </div>
    )
  }

  if (unsupportedArch) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[#0B0B0F] p-6">
        <div className="max-w-xl rounded-2xl border border-glass-border bg-[#1a1a2e] p-6 shadow-xl">
          <div className="mb-4 flex justify-center">
            <ZyvorLogoMark height={32} />
          </div>
          <h1 className="mb-2 text-xl font-semibold">Apple Silicon required</h1>
          <p className="mb-4 text-sm text-glass-muted">
            Hypercluster Desktop is built for <strong>Apple Silicon (arm64)</strong> only. Intel-based
            Mac support has ended — this Mac reports <code className="text-glass-accent">{hostArch}</code>.
          </p>
          <p className="mb-4 text-sm text-glass-muted">
            If you see a Rosetta or Intel compatibility warning, download the{' '}
            <strong>arm64</strong> build from Zyvor and run it on an M-series Mac.
          </p>
          <div className="flex justify-end">
            <button
              type="button"
              className="btn-primary text-sm"
              onClick={() => {
                void getCurrentWindow().close()
              }}
            >
              Quit
            </button>
          </div>
        </div>
      </div>
    )
  }

  if (accepted) return <>{children}</>

  return (
    <div className="flex min-h-screen items-center justify-center bg-[#0B0B0F] p-6">
      <div className="max-w-xl rounded-2xl border border-glass-border bg-[#1a1a2e] p-6 shadow-xl">
        <div className="mb-4 flex justify-center">
          <ZyvorLogoMark height={32} />
        </div>
        <h1 className="mb-2 text-xl font-semibold">Zyvor License Agreement</h1>
        <p className="mb-4 text-sm text-glass-muted">
          Hypercluster Desktop is proprietary software from ZyvorAI Labs Private Limited (
          <a className="text-glass-accent" href="https://zyvor.dev">
            zyvor.dev
          </a>
          ). You must accept the license before using the application.
        </p>
        <pre className="mb-4 max-h-64 overflow-y-auto rounded-xl border border-glass-border bg-black/30 p-3 text-xs leading-relaxed text-glass-muted whitespace-pre-wrap">
          {summary || 'License text unavailable.'}
        </pre>
        {error && <p className="mb-3 text-sm text-red-300">{error}</p>}
        <div className="flex justify-end gap-2">
          <button
            type="button"
            className="btn-ghost text-sm"
            onClick={() => {
              void getCurrentWindow().close()
            }}
          >
            Decline &amp; Quit
          </button>
          <button type="button" className="btn-primary text-sm" onClick={accept}>
            I Accept
          </button>
        </div>
      </div>
    </div>
  )
}
