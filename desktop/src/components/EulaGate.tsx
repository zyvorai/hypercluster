import { useEffect, useState, type ReactNode } from 'react'
import { ZyvorLogoMark } from './ZyvorBrand'
import appIconUrl from '../assets/brand/app-icon.svg'
import { invoke } from '@tauri-apps/api/core'
import { getCurrentWindow } from '@tauri-apps/api/window'

const isMac = /^Mac/.test(navigator.platform)
const deviceWord = isMac ? 'Mac' : 'PC'

type TrialStatus = {
  active: boolean
  expired: boolean
  licensed: boolean
  daysRemaining: number
  trialStartedAt?: string
  trialEndsAt?: string
  salesEmail: string
  trialDays: number
}

function GatePanel({ children }: { children: ReactNode }) {
  return (
    <div className="flex min-h-screen items-center justify-center p-6">
      <div className="max-w-xl rounded-glass-lg border border-glass-border bg-glass-panel/90 p-8 shadow-zyvor-card backdrop-blur-2xl">
        <div className="mb-5 flex items-center justify-center gap-4">
          <img
            src={appIconUrl}
            alt=""
            className="h-14 w-14 rounded-[22%] shadow-zyvor-glow ring-1 ring-white/10"
          />
          <ZyvorLogoMark height={30} />
        </div>
        {children}
      </div>
    </div>
  )
}

export function EulaGate({ children }: { children: React.ReactNode }) {
  const [loading, setLoading] = useState(true)
  const [accepted, setAccepted] = useState(false)
  const [trialUsable, setTrialUsable] = useState(false)
  const [trialStatus, setTrialStatus] = useState<TrialStatus | null>(null)
  const [unsupportedArch, setUnsupportedArch] = useState(false)
  const [hostArch, setHostArch] = useState('')
  const [summary, setSummary] = useState('')
  const [error, setError] = useState('')

  const loadTrial = async () => {
    await invoke('trial_ensure_started_cmd')
    const status = await invoke<TrialStatus>('trial_status_cmd')
    const usable = await invoke<boolean>('trial_is_usable_cmd')
    setTrialStatus(status)
    setTrialUsable(usable)
  }

  useEffect(() => {
    let cancelled = false
    ;(async () => {
      try {
        const arch = await invoke<string>('host_cpu_arch_cmd')
        // ARM64 requirement only applies on macOS; skip the check on Windows/Linux.
        const needsArm = isMac ? await invoke<boolean>('macos_arm64_required_cmd') : false
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
          await loadTrial()
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
      await loadTrial()
    } catch (e) {
      setError(String(e))
    }
  }

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center text-glass-muted">
        <div className="flex flex-col items-center gap-4">
          <img
            src={appIconUrl}
            alt=""
            className="h-16 w-16 animate-pulse rounded-[22%] shadow-zyvor-glow"
          />
          <p>Loading Hypercluster…</p>
        </div>
      </div>
    )
  }

  if (unsupportedArch) {
    return (
      <GatePanel>
        <h1 className="mb-2 text-xl font-semibold">Apple Silicon required</h1>
        <p className="mb-4 text-sm text-glass-muted">
          Hypercluster Desktop is built for <strong>Apple Silicon (arm64)</strong> only. Intel-based
          Mac support has ended — this Mac reports{' '}
          <code className="text-glass-accent">{hostArch}</code>.
        </p>
        <p className="mb-4 text-sm text-glass-muted">
          If you see a Rosetta or Intel compatibility warning, download the <strong>arm64</strong>{' '}
          build from Zyvor and run it on an M-series Mac.
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
      </GatePanel>
    )
  }

  if (accepted && !trialUsable) {
    const salesEmail = trialStatus?.salesEmail ?? 'sales@zyvor.dev'
    const trialDays = trialStatus?.trialDays ?? 30
    return (
      <GatePanel>
        <h1 className="mb-2 text-xl font-semibold">Trial expired</h1>
        <p className="mb-4 text-sm text-glass-muted">
          Your {trialDays}-day Hypercluster Desktop trial on this {deviceWord} has ended. Reinstalling
          the app does not start a new trial.
        </p>
        <p className="mb-4 text-sm text-glass-muted">
          To continue using Hypercluster Desktop, contact Zyvor sales for a license:
        </p>
        <p className="mb-4 text-center">
          <a className="text-lg font-medium text-glass-accent" href={`mailto:${salesEmail}`}>
            {salesEmail}
          </a>
        </p>
        {trialStatus?.trialEndsAt && (
          <p className="mb-4 text-xs text-glass-muted">
            Trial ended: {new Date(trialStatus.trialEndsAt).toLocaleDateString()}
          </p>
        )}
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
      </GatePanel>
    )
  }

  if (accepted) return <>{children}</>

  return (
    <GatePanel>
      <h1 className="mb-2 text-xl font-semibold">Zyvor License Agreement</h1>
      <p className="mb-4 text-sm text-glass-muted">
        Hypercluster Desktop is proprietary software from ZyvorAI Labs Private Limited (
        <a className="text-glass-accent" href="https://zyvor.dev">
          zyvor.dev
        </a>
        ). You must accept the license before using the application.
      </p>
      <p className="mb-4 rounded-xl border border-glass-accent/20 bg-glass-accent/5 px-3 py-2 text-sm text-glass-muted">
        Includes a <strong>{trialStatus?.trialDays ?? 30}-day trial</strong> on this {deviceWord}. The trial
        starts when you accept and cannot be reset by uninstalling and reinstalling.
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
          I Accept &amp; Start Trial
        </button>
      </div>
    </GatePanel>
  )
}
