import { useCallback, useEffect, useState } from 'react'
import { listen } from '@tauri-apps/api/event'
import { ClusterCard } from './components/ClusterCard'
import { CommandPalette } from './components/CommandPalette'
import { GlassCard } from './components/GlassCard'
import { LogConsole } from './components/LogConsole'
import {
  buildClusterConf,
  createCluster,
  defaultWizard,
  importCluster,
  listClusters,
  pickClusterConf,
  resolveBinary,
  statusJson,
  getSettings,
} from './lib/api'
import type { ClusterEntry, ParsedStage, View, WizardForm } from './lib/types'

function IpTags({
  label,
  ips,
  onChange,
}: {
  label: string
  ips: string[]
  onChange: (ips: string[]) => void
}) {
  const [draft, setDraft] = useState('')
  return (
    <div>
      <label className="mb-1 block text-sm text-glass-muted">{label}</label>
      <div className="flex flex-wrap gap-2 rounded-xl border border-glass-border bg-black/20 p-2">
        {ips.map((ip) => (
          <span
            key={ip}
            className="flex items-center gap-1 rounded-full bg-glass-accent/20 px-3 py-1 text-sm"
          >
            {ip}
            <button
              type="button"
              className="text-glass-muted hover:text-white"
              onClick={() => onChange(ips.filter((x) => x !== ip))}
            >
              ×
            </button>
          </span>
        ))}
        <input
          className="min-w-[120px] flex-1 bg-transparent text-sm outline-none"
          placeholder="Add IP, Enter"
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && draft.trim()) {
              onChange([...ips, draft.trim()])
              setDraft('')
            }
          }}
        />
      </div>
    </div>
  )
}

export default function App() {
  const [view, setView] = useState<View>('dashboard')
  const [clusters, setClusters] = useState<ClusterEntry[]>([])
  const [active, setActive] = useState<ClusterEntry | null>(null)
  const [binaryPath, setBinaryPath] = useState('')
  const [nodeStats, setNodeStats] = useState<Record<string, { ready: number; total: number }>>({})
  const [wizard, setWizard] = useState<WizardForm>(defaultWizard())
  const [wizardStep, setWizardStep] = useState(0)
  const [logs, setLogs] = useState<string[]>([])
  const [stage, setStage] = useState<ParsedStage | null>(null)
  const [running, setRunning] = useState(false)
  const [activeCommand, setActiveCommand] = useState('')
  const [paletteOpen, setPaletteOpen] = useState(false)
  const [destroyConfirm, setDestroyConfirm] = useState('')
  const [removeNode, setRemoveNode] = useState('')
  const [settingsBin, setSettingsBin] = useState('')
  const [deployAfterWizard, setDeployAfterWizard] = useState(false)

  const refresh = useCallback(async () => {
    setClusters(await listClusters())
    setBinaryPath(await resolveBinary())
  }, [])

  useEffect(() => {
    refresh()
    getSettings().then((s) => setSettingsBin(s.hypercluster_binary ?? ''))
  }, [refresh])

  useEffect(() => {
    let unlisten: (() => void) | undefined
    ;(async () => {
      unlisten = await listen<ClusterEntry>('hc-cluster-imported', () => {
        refresh()
      })
    })()
    return () => unlisten?.()
  }, [refresh])

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault()
        setPaletteOpen(true)
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [])

  useEffect(() => {
    let u1: (() => void) | undefined
    let u2: (() => void) | undefined
    let u3: (() => void) | undefined
    ;(async () => {
      u1 = await listen<{ plain?: string; line?: string }>('hc-log-line', (ev) => {
        setLogs((prev) => [...prev, ev.payload.plain ?? ev.payload.line ?? ''])
      })
      u2 = await listen<ParsedStage>('hc-stage', (ev) => setStage(ev.payload))
      u3 = await listen('hc-exit', () => setRunning(false))
    })()
    return () => {
      u1?.()
      u2?.()
      u3?.()
    }
  }, [])

  useEffect(() => {
    const loadStats = async (list: ClusterEntry[]) => {
      const stats: Record<string, { ready: number; total: number }> = {}
      for (const c of list) {
        try {
          const s = await statusJson(c.config_path)
          stats[c.name] = { ready: s.ready, total: s.total }
        } catch {
          /* kubeconfig may not exist yet */
        }
      }
      setNodeStats(stats)
    }
    if (clusters.length) loadStats(clusters)
  }, [clusters])

  const runOn = async (
    cluster: ClusterEntry,
    command: string,
    opts?: { force?: boolean; dryRun?: boolean; args?: string[] },
  ) => {
    const { runCommand } = await import('./lib/api')
    setActive(cluster)
    setActiveCommand(
      [command, ...(opts?.args ?? [])].join(' ') + (opts?.dryRun ? ' (dry-run)' : ''),
    )
    setView('deploy')
    setLogs([])
    setStage(null)
    setRunning(true)
    await runCommand({
      clusterName: cluster.name,
      configPath: cluster.config_path,
      command,
      force: opts?.force,
      dryRun: opts?.dryRun,
      args: opts?.args,
    })
    await refresh()
  }

  const saveWizard = async () => {
    const conf = buildClusterConf(wizard)
    const entry = await createCluster(wizard.clusterName, conf, wizard.k8sDistro)
    await refresh()
    setActive(entry)
    if (deployAfterWizard) {
      await runOn(entry, 'deploy')
      return
    }
    setView('dashboard')
  }

  const handleImportConf = async () => {
    const path = await pickClusterConf()
    if (!path) return
    const entry = await importCluster(path)
    await refresh()
    setActive(entry)
    setView('dashboard')
  }

  const nav: { id: View; label: string }[] = [
    { id: 'dashboard', label: 'Dashboard' },
    { id: 'wizard', label: 'Create Cluster' },
    { id: 'operations', label: 'Operations' },
    { id: 'settings', label: 'Settings' },
  ]

  return (
    <div className="flex min-h-screen">
      <aside className="glass-panel m-3 flex w-56 flex-col gap-1 p-3">
        <h1 className="px-2 py-3 text-lg font-bold tracking-tight">Hypercluster</h1>
        {nav.map((n) => (
          <button
            key={n.id}
            type="button"
            className={`rounded-xl px-3 py-2 text-left text-sm ${view === n.id ? 'bg-glass-accent/25 text-white' : 'text-glass-muted hover:bg-white/5'}`}
            onClick={() => setView(n.id)}
          >
            {n.label}
          </button>
        ))}
        <p className="mt-auto px-2 text-[10px] text-glass-muted">⌘K command palette</p>
      </aside>

      <main className="flex-1 overflow-y-auto p-6">
        {view === 'dashboard' && (
          <div>
            <div className="mb-6 flex items-end justify-between">
              <div>
                <h2 className="text-2xl font-semibold">Clusters</h2>
                <p className="text-sm text-glass-muted">hypercluster @ {binaryPath || '…'}</p>
              </div>
              <div className="flex gap-2">
                <button type="button" className="btn-ghost" onClick={handleImportConf}>
                  Import cluster.conf
                </button>
                <button type="button" className="btn-primary" onClick={() => setView('wizard')}>
                  + New Cluster
                </button>
              </div>
            </div>
            {clusters.length === 0 && (
              <GlassCard className="mb-6">
                <p className="text-glass-muted">
                  No clusters in the desktop registry yet. Import an existing{' '}
                  <code className="text-white">cluster.conf</code> or create one with the wizard.
                </p>
              </GlassCard>
            )}
            <div className="mb-6 grid grid-cols-3 gap-4">
              <GlassCard>
                <p className="text-sm text-glass-muted">Clusters</p>
                <p className="text-3xl font-semibold">{clusters.length}</p>
              </GlassCard>
              <GlassCard>
                <p className="text-sm text-glass-muted">Ready nodes</p>
                <p className="text-3xl font-semibold">
                  {Object.values(nodeStats).reduce((a, s) => a + s.ready, 0)}
                </p>
              </GlassCard>
              <GlassCard>
                <p className="text-sm text-glass-muted">Active job</p>
                <p className="text-3xl font-semibold">{running ? '1' : '0'}</p>
              </GlassCard>
            </div>
            <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
              {clusters.map((c) => (
                <ClusterCard
                  key={c.id}
                  cluster={c}
                  nodesReady={nodeStats[c.name]?.ready}
                  nodesTotal={nodeStats[c.name]?.total}
                  onOpen={() => {
                    setActive(c)
                    setView('operations')
                  }}
                  onDeploy={() => runOn(c, 'deploy')}
                />
              ))}
            </div>
          </div>
        )}

        {view === 'wizard' && (
          <GlassCard className="max-w-2xl">
            <h2 className="mb-4 text-xl font-semibold">Create Cluster — Step {wizardStep + 1}/5</h2>
            {wizardStep === 0 && (
              <div className="space-y-3">
                <input
                  className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2"
                  value={wizard.clusterName}
                  onChange={(e) => setWizard({ ...wizard, clusterName: e.target.value })}
                  placeholder="Cluster name"
                />
                <select
                  className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2"
                  value={wizard.k8sDistro}
                  onChange={(e) =>
                    setWizard({ ...wizard, k8sDistro: e.target.value as 'k3s' | 'kubespray' })
                  }
                >
                  <option value="k3s">k3s (remote platform stack)</option>
                  <option value="kubespray">Kubespray (upstream HA)</option>
                </select>
                <input
                  className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2"
                  value={wizard.kubeVersion}
                  onChange={(e) => setWizard({ ...wizard, kubeVersion: e.target.value })}
                  placeholder="Kubernetes version"
                />
              </div>
            )}
            {wizardStep === 1 && (
              <div className="space-y-4">
                <IpTags
                  label="Control plane IPs"
                  ips={wizard.controlPlaneIps}
                  onChange={(ips) => setWizard({ ...wizard, controlPlaneIps: ips })}
                />
                <IpTags
                  label="Worker IPs"
                  ips={wizard.workerIps}
                  onChange={(ips) => setWizard({ ...wizard, workerIps: ips })}
                />
                <input
                  className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2"
                  value={wizard.sshUser}
                  onChange={(e) => setWizard({ ...wizard, sshUser: e.target.value })}
                  placeholder="SSH user"
                />
                <input
                  className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2"
                  value={wizard.sshKey}
                  onChange={(e) => setWizard({ ...wizard, sshKey: e.target.value })}
                  placeholder="SSH key path"
                />
                <button
                  type="button"
                  className="btn-ghost text-sm"
                  onClick={async () => {
                    const { pickSshKey } = await import('./lib/api')
                    const path = await pickSshKey()
                    if (path) setWizard({ ...wizard, sshKey: path })
                  }}
                >
                  Browse SSH key…
                </button>
              </div>
            )}
            {wizardStep === 2 && (
              <div className="space-y-3">
                <input
                  className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2"
                  value={wizard.kubePodsSubnet}
                  onChange={(e) => setWizard({ ...wizard, kubePodsSubnet: e.target.value })}
                  placeholder="Pod CIDR"
                />
                <input
                  className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2"
                  value={wizard.cniPlugin}
                  onChange={(e) => setWizard({ ...wizard, cniPlugin: e.target.value })}
                  placeholder="CNI plugin"
                />
              </div>
            )}
            {wizardStep === 3 && (
              <div className="space-y-3">
                <label className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={wizard.metallbEnabled}
                    onChange={(e) => setWizard({ ...wizard, metallbEnabled: e.target.checked })}
                  />
                  MetalLB
                </label>
                {wizard.metallbEnabled && (
                  <input
                    className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2"
                    value={wizard.metallbIpPool}
                    onChange={(e) => setWizard({ ...wizard, metallbIpPool: e.target.value })}
                    placeholder="MetalLB IP pool"
                  />
                )}
                <label className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={wizard.kubevirtEnabled}
                    onChange={(e) => setWizard({ ...wizard, kubevirtEnabled: e.target.checked })}
                  />
                  KubeVirt + CDI
                </label>
              </div>
            )}
            {wizardStep === 4 && (
              <>
                <pre className="max-h-64 overflow-auto rounded-xl bg-black/40 p-3 text-xs">
                  {buildClusterConf(wizard)}
                </pre>
                <label className="mt-4 flex items-center gap-2 text-sm text-glass-muted">
                  <input
                    type="checkbox"
                    checked={deployAfterWizard}
                    onChange={(e) => setDeployAfterWizard(e.target.checked)}
                  />
                  Deploy immediately after saving
                </label>
              </>
            )}
            <div className="mt-6 flex justify-between">
              <button
                type="button"
                className="btn-ghost"
                disabled={wizardStep === 0}
                onClick={() => setWizardStep((s) => s - 1)}
              >
                Back
              </button>
              {wizardStep < 4 ? (
                <button
                  type="button"
                  className="btn-primary"
                  onClick={() => setWizardStep((s) => s + 1)}
                >
                  Next
                </button>
              ) : (
                <button type="button" className="btn-primary" onClick={saveWizard}>
                  Save & Create
                </button>
              )}
            </div>
          </GlassCard>
        )}

        {view === 'deploy' && active && (
          <div>
            <h2 className="mb-2 text-xl font-semibold">
              {active.name} — {activeCommand}
              {running ? ' (running)' : ''}
            </h2>
            {stage && (
              <GlassCard className="mb-4">
                <p className="text-sm text-glass-muted">
                  Stage {stage.current}/{stage.total}
                </p>
                <p className="font-medium">{stage.label}</p>
              </GlassCard>
            )}
            <LogConsole lines={logs} />
            {running && (
              <button
                type="button"
                className="btn-ghost mt-4"
                onClick={async () => {
                  const { cancelRun } = await import('./lib/api')
                  await cancelRun(active.name)
                  setRunning(false)
                }}
              >
                Cancel job
              </button>
            )}
          </div>
        )}

        {view === 'operations' && (
          <div className="max-w-xl space-y-4">
            <h2 className="text-xl font-semibold">Day-2 Operations</h2>
            <select
              className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2"
              value={active?.name ?? ''}
              onChange={(e) =>
                setActive(clusters.find((c) => c.name === e.target.value) ?? null)
              }
            >
              <option value="">Select cluster</option>
              {clusters.map((c) => (
                <option key={c.id} value={c.name}>
                  {c.name}
                </option>
              ))}
            </select>
            {active && (
              <GlassCard className="space-y-2">
                {[
                  'preflight',
                  'deploy',
                  'test',
                  'status',
                  'scale',
                  'upgrade',
                  'fetch-kubeconfig',
                  'merge-kubeconfig',
                  'unlock',
                ].map((cmd) => (
                  <button
                    key={cmd}
                    type="button"
                    className="btn-ghost w-full text-left"
                    onClick={() => runOn(active, cmd)}
                  >
                    {cmd}
                  </button>
                ))}
                <button
                  type="button"
                  className="btn-ghost w-full text-left"
                  onClick={() => runOn(active, 'test', { args: ['--full'] })}
                >
                  test --full
                </button>
                <button
                  type="button"
                  className="btn-ghost w-full text-left"
                  onClick={() => import('./lib/api').then((m) => m.revealConfig(active.config_path))}
                >
                  reveal cluster.conf in Finder
                </button>
                <button
                  type="button"
                  className="btn-ghost w-full text-left"
                  onClick={() => runOn(active, 'deploy', { dryRun: true })}
                >
                  dry-run deploy
                </button>
                <input
                  className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2"
                  placeholder="Node name to remove"
                  value={removeNode}
                  onChange={(e) => setRemoveNode(e.target.value)}
                />
                <button
                  type="button"
                  className="btn-ghost w-full"
                  disabled={!removeNode}
                  onClick={() => runOn(active, 'remove-node', { args: [removeNode], force: true })}
                >
                  remove-node
                </button>
                <input
                  className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2"
                  placeholder={`Type ${active.name} to destroy`}
                  value={destroyConfirm}
                  onChange={(e) => setDestroyConfirm(e.target.value)}
                />
                <button
                  type="button"
                  className="w-full rounded-xl bg-red-600/80 px-4 py-2"
                  disabled={destroyConfirm !== active.name}
                  onClick={() => runOn(active, 'destroy', { force: true })}
                >
                  Destroy cluster
                </button>
              </GlassCard>
            )}
          </div>
        )}

        {view === 'settings' && (
          <GlassCard className="max-w-lg space-y-4">
            <h2 className="text-xl font-semibold">Settings</h2>
            <p className="text-sm text-glass-muted">Resolved binary: {binaryPath}</p>
            <input
              className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2"
              placeholder="Custom hypercluster binary path"
              value={settingsBin}
              onChange={(e) => setSettingsBin(e.target.value)}
            />
            <button
              type="button"
              className="btn-primary"
              onClick={async () => {
                const { setSettings } = await import('./lib/api')
                await setSettings({ hypercluster_binary: settingsBin || null })
                setBinaryPath(await resolveBinary())
              }}
            >
              Save
            </button>
            <button
              type="button"
              className="btn-ghost"
              onClick={async () => {
                const path = await pickClusterConf()
                if (path) {
                  await importCluster(path)
                  await refresh()
                }
              }}
            >
              Import cluster.conf…
            </button>
            <button
              type="button"
              className="btn-ghost"
              onClick={() => import('./lib/api').then((m) => m.openDataDir())}
            >
              Open data directory
            </button>
          </GlassCard>
        )}
      </main>

      <CommandPalette
        open={paletteOpen}
        onClose={() => setPaletteOpen(false)}
        clusters={clusters}
        onRun={(c, cmd) => runOn(c, cmd)}
      />
    </div>
  )
}
