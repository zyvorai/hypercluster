import { lazy, Suspense, useEffect, useState } from 'react'
import type { ClusterSpec, PreflightJson, StudioExpertLevel, StudioStep } from '../lib/types'
import { buildClusterConfFromSpec, preflightJson, vmsJson } from '../lib/api'
import { isDistroDeployReady, DISTRO_CAPABILITIES } from '../lib/distroCapabilities'
import { STUDIO_TEMPLATES } from '../lib/templates'
import { CiliumStudio } from './CiliumStudio'
import { GlassCard } from './GlassCard'
import { LivePreviewPanel } from './LivePreviewPanel'
import { NodeCanvas } from './NodeCanvas'
import { PlatformStackCards } from './PlatformStackCards'
import { KubeVirtStudio } from './KubeVirtStudio'
import { TestResultsPanel } from './TestResultsPanel'

const SettingsSearch = lazy(() =>
  import('./SettingsSearch').then((m) => ({ default: m.SettingsSearch })),
)

const ALL_STEPS: { id: StudioStep; label: string; expert: StudioExpertLevel[] }[] = [
  { id: 'intent', label: 'Intent', expert: ['basic', 'advanced', 'expert'] },
  { id: 'nodes', label: 'Nodes', expert: ['basic', 'advanced', 'expert'] },
  { id: 'plan', label: 'Deploy', expert: ['basic', 'advanced', 'expert'] },
  { id: 'distro', label: 'Distro', expert: ['advanced', 'expert'] },
  { id: 'network', label: 'Network', expert: ['advanced', 'expert'] },
  { id: 'platform', label: 'Platform', expert: ['advanced', 'expert'] },
  { id: 'validate', label: 'Validate', expert: ['advanced', 'expert'] },
]

export function ClusterStudio({
  spec,
  onChange,
  step,
  onStep,
  onSave,
  onDeploy,
  onBack,
  expertLevel,
  onExpertLevel,
  saving,
  tempConfPath,
}: {
  spec: ClusterSpec
  onChange: (spec: ClusterSpec) => void
  step: StudioStep
  onStep: (step: StudioStep) => void
  onSave: () => void
  onDeploy: () => void
  onBack: () => void
  expertLevel: StudioExpertLevel
  onExpertLevel: (level: StudioExpertLevel) => void
  saving?: boolean
  tempConfPath?: string | null
}) {
  const [preflight, setPreflight] = useState<PreflightJson | null>(null)
  const [preflightLoading, setPreflightLoading] = useState(false)
  const [preflightErr, setPreflightErr] = useState('')
  const [searchOpen, setSearchOpen] = useState(false)
  const [vms, setVms] = useState<Awaited<ReturnType<typeof vmsJson>> | null>(null)
  const deployReady = isDistroDeployReady(spec.k8sDistro)
  const STEPS = ALL_STEPS.filter((s) => s.expert.includes(expertLevel))

  useEffect(() => {
    if (tempConfPath && spec.kubevirtEnabled) {
      vmsJson(tempConfPath).then(setVms).catch(() => setVms(null))
    }
  }, [tempConfPath, spec.kubevirtEnabled])

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'f') {
        e.preventDefault()
        setSearchOpen(true)
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [])

  const runPreflight = async () => {
    if (!tempConfPath) {
      setPreflightErr('Save cluster first to run preflight')
      return
    }
    setPreflightLoading(true)
    setPreflightErr('')
    try {
      setPreflight(await preflightJson(tempConfPath))
    } catch (e) {
      setPreflightErr(String(e))
      setPreflight(null)
    } finally {
      setPreflightLoading(false)
    }
  }

  const stepIdx = STEPS.findIndex((s) => s.id === step)

  return (
    <div className="flex gap-6">
      <div className="min-w-0 flex-1 space-y-4">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div className="flex items-center gap-2">
            <button type="button" className="btn-ghost text-sm" onClick={onBack}>
              ← Hub
            </button>
            <h2 className="text-xl font-semibold">Cluster Studio</h2>
          </div>
          <button type="button" className="text-xs text-glass-accent" onClick={() => setSearchOpen(true)}>
            {expertLevel === 'expert' ? 'Search 445+ settings ⌘F' : 'Search settings ⌘F'}
          </button>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          {(['basic', 'advanced', 'expert'] as StudioExpertLevel[]).map((level) => (
            <button
              key={level}
              type="button"
              className={`rounded-lg px-3 py-1 text-xs capitalize ${
                expertLevel === level ? 'bg-glass-accent/30' : 'bg-white/5 text-glass-muted'
              }`}
              onClick={() => {
                onExpertLevel(level)
                if (!ALL_STEPS.find((s) => s.id === step)?.expert.includes(level)) {
                  onStep('intent')
                }
              }}
            >
              {level}
            </button>
          ))}
        </div>

        <div className="flex flex-wrap gap-1">
          {STEPS.map((s, i) => (
            <button
              key={s.id}
              type="button"
              className={`rounded-lg px-3 py-1 text-sm ${
                step === s.id ? 'bg-glass-accent/30 text-white' : 'bg-white/5 text-glass-muted'
              }`}
              onClick={() => onStep(s.id)}
            >
              {i + 1}. {s.label}
            </button>
          ))}
        </div>

        {step === 'intent' && (
          <GlassCard className="space-y-4">
            <h3 className="font-medium">Cluster identity</h3>
            <input
              className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2"
              value={spec.clusterName}
              onChange={(e) => onChange({ ...spec, clusterName: e.target.value })}
              placeholder="Cluster name"
            />
            <div className="grid gap-3 sm:grid-cols-2">
              {STUDIO_TEMPLATES.map((t) => (
                <button
                  key={t.id}
                  type="button"
                  className={`rounded-xl border p-3 text-left ${
                    spec.templateId === t.id ? 'border-glass-accent bg-glass-accent/10' : 'border-glass-border'
                  }`}
                  onClick={() => onChange({ ...spec, ...t.defaults, templateId: t.id })}
                >
                  <p className="text-xs text-glass-accent">{t.intent}</p>
                  <p className="font-medium">{t.label}</p>
                </button>
              ))}
            </div>
          </GlassCard>
        )}

        {step === 'distro' && (
          <GlassCard className="space-y-3">
            <h3 className="font-medium">Kubernetes distribution</h3>
            <div className="grid gap-2 sm:grid-cols-2">
              {DISTRO_CAPABILITIES.map((d) => (
                <button
                  key={d.id}
                  type="button"
                  className={`rounded-xl border p-3 text-left ${
                    spec.k8sDistro === d.id ? 'border-glass-accent bg-glass-accent/10' : 'border-glass-border'
                  }`}
                  onClick={() =>
                    onChange({
                      ...spec,
                      k8sDistro: d.id,
                      deployModel: d.id === 'talos' ? 'talos' : 'ssh',
                    })
                  }
                >
                  <div className="flex items-center justify-between">
                    <span className="font-medium">{d.label}</span>
                    {!d.deployReady && (
                      <span className="rounded bg-amber-500/20 px-1.5 text-xs text-amber-200">Preview</span>
                    )}
                  </div>
                  {d.note && <p className="mt-1 text-xs text-glass-muted">{d.note}</p>}
                </button>
              ))}
            </div>
            <input
              className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2"
              value={spec.kubeVersion}
              onChange={(e) => onChange({ ...spec, kubeVersion: e.target.value })}
              placeholder="Version"
            />
          </GlassCard>
        )}

        {step === 'nodes' && <NodeCanvas spec={spec} onChange={onChange} />}

        {step === 'network' && <CiliumStudio spec={spec} onChange={onChange} />}

        {step === 'platform' && (
          <div className="space-y-4">
            <PlatformStackCards spec={spec} onChange={onChange} />
            {spec.kubevirtEnabled && (
              <KubeVirtStudio spec={spec} vms={vms} onChange={onChange} onRefreshVms={() => tempConfPath && vmsJson(tempConfPath).then(setVms)} />
            )}
          </div>
        )}

        {step === 'validate' && (
          <GlassCard className="space-y-3">
            <h3 className="font-medium">Preflight validation</h3>
            <p className="text-sm text-glass-muted">
              Saves config to registry, then runs <code>hypercluster preflight --json</code>.
            </p>
            <button type="button" className="btn-primary" disabled={preflightLoading} onClick={runPreflight}>
              {preflightLoading ? 'Running…' : 'Run preflight'}
            </button>
            {preflightErr && <p className="text-sm text-red-300">{preflightErr}</p>}
            {preflight && (
              <ul className="space-y-1 text-sm">
                {preflight.checks.map((c) => (
                  <li key={c.name} className={c.passed ? 'text-emerald-300' : 'text-red-300'}>
                    {c.passed ? 'PASS' : 'FAIL'} — {c.name}
                  </li>
                ))}
              </ul>
            )}
          </GlassCard>
        )}

        {step === 'plan' && (
          <GlassCard className="space-y-3">
            <h3 className="font-medium">Review & deploy</h3>
            {!deployReady && (
              <p className="text-sm text-amber-200">
                {spec.k8sDistro} deploy is preview-only — choose k3s or Kubespray for full deploy.
              </p>
            )}
            <pre className="max-h-48 overflow-auto rounded-xl bg-black/30 p-3 text-xs">
              {buildClusterConfFromSpec(spec)}
            </pre>
            <TestResultsPanel
              results={
                preflight
                  ? {
                      pass: preflight.checks.filter((c) => c.passed).length,
                      fail: preflight.checks.filter((c) => !c.passed).length,
                      checks: preflight.checks.map((c) => ({ name: c.name, passed: c.passed })),
                    }
                  : null
              }
              loading={false}
              error=""
            />
          </GlassCard>
        )}

        <div className="flex justify-between pt-2">
          <button
            type="button"
            className="btn-ghost"
            disabled={stepIdx <= 0}
            onClick={() => onStep(STEPS[Math.max(0, stepIdx - 1)].id)}
          >
            Back
          </button>
          <div className="flex gap-2">
            <button type="button" className="btn-ghost" disabled={saving} onClick={onSave}>
              Save cluster
            </button>
            {stepIdx < STEPS.length - 1 ? (
              <button
                type="button"
                className="btn-primary"
                onClick={() => onStep(STEPS[Math.min(STEPS.length - 1, stepIdx + 1)].id)}
              >
                Next
              </button>
            ) : (
              <button
                type="button"
                className="btn-primary"
                disabled={!deployReady || saving}
                onClick={onDeploy}
              >
                Deploy
              </button>
            )}
          </div>
        </div>
      </div>

      <div className="hidden w-72 shrink-0 lg:block">
        <LivePreviewPanel spec={spec} />
      </div>

      <Suspense fallback={null}>
        <SettingsSearch
          open={searchOpen}
          spec={spec}
          onChange={onChange}
          onClose={() => setSearchOpen(false)}
        />
      </Suspense>
    </div>
  )
}
