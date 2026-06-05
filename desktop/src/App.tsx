import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { listen } from '@tauri-apps/api/event'
import { ClusterCard } from './components/ClusterCard'
import { ClusterDetailView } from './components/ClusterDetailView'
import { ClusterRegistryList } from './components/ClusterRegistryList'
import { CommandPalette, type PaletteSelection } from './components/CommandPalette'
import { CreateClusterHub } from './components/CreateClusterHub'
import { ClusterStudio } from './components/ClusterStudio'
import { QuickDeployStudio } from './components/QuickDeployStudio'
import { DeployPipeline } from './components/DeployPipeline'
import { GlassCard } from './components/GlassCard'
import { DeployOpsCenter } from './components/DeployOpsCenter'
import { StructuredLogConsole } from './components/StructuredLogConsole'
import { GlobalSearch, buildSearchIndex, type SearchResult } from './components/GlobalSearch'
import {
  buildClusterConfFromSpec,
  createCluster,
  updateClusterByPath,
  importCluster,
  listClusters,
  pickClusterConf,
  readClusterConf,
  resolveBinary,
  statusJson,
  vmsJson,
  getSettings,
} from './lib/api'
import { defaultClusterSpec, mergeClusterSpec, parseClusterSpec } from './lib/clusterSpec'
import { applyStudioTemplate } from './lib/templates'
import { intentById } from './lib/studioIntents'
import { AppBrandHeader, ZyvorFooter } from './components/ZyvorBrand'
import { ConfEditor } from './components/ConfEditor'
import type {
  ClusterEntry,
  JobExitPayload,
  ParsedStage,
  View,
  ClusterSpec,
  StudioStep,
  StudioIntentId,
  StudioExpertLevel,
  StatusJson,
  VmsJson,
} from './lib/types'

export default function App() {
  const [view, setView] = useState<View>('dashboard')
  const [clusters, setClusters] = useState<ClusterEntry[]>([])
  const [active, setActive] = useState<ClusterEntry | null>(null)
  const [binaryPath, setBinaryPath] = useState('')
  const [nodeStats, setNodeStats] = useState<Record<string, { ready: number; total: number }>>({})
  const [logs, setLogs] = useState<string[]>([])
  const [stage, setStage] = useState<ParsedStage | null>(null)
  const [running, setRunning] = useState(false)
  const [runningCluster, setRunningCluster] = useState<string | null>(null)
  const [activeCommand, setActiveCommand] = useState('')
  const [lastJobSuccess, setLastJobSuccess] = useState<boolean | null>(null)
  const [paletteOpen, setPaletteOpen] = useState(false)
  const [globalSearchOpen, setGlobalSearchOpen] = useState(false)
  const [statusByCluster, setStatusByCluster] = useState<Record<string, StatusJson | null>>({})
  const [vmsByCluster, setVmsByCluster] = useState<Record<string, VmsJson | null>>({})
  const [destroyConfirm, setDestroyConfirm] = useState('')
  const [removeNode, setRemoveNode] = useState('')
  const [settingsBin, setSettingsBin] = useState('')
  const [confDraft, setConfDraft] = useState('')
  const [confSaving, setConfSaving] = useState(false)
  const [editorReturnView, setEditorReturnView] = useState<View>('cluster')
  const [detailRefreshKey, setDetailRefreshKey] = useState(0)
  const [preflightPromptCluster, setPreflightPromptCluster] = useState<ClusterEntry | null>(null)
  const [returnViewAfterJob, setReturnViewAfterJob] = useState<View | null>(null)
  const [studioSpec, setStudioSpec] = useState<ClusterSpec>(() => defaultClusterSpec())
  const [studioStep, setStudioStep] = useState<StudioStep>('intent')
  const [studioSaving, setStudioSaving] = useState(false)
  const [studioSavedPath, setStudioSavedPath] = useState<string | null>(null)
  const [studioIntentId, setStudioIntentId] = useState<StudioIntentId>('kubernetes')
  const [studioExpertLevel, setStudioExpertLevel] = useState<StudioExpertLevel>('advanced')
  const returnViewRef = useRef<View | null>(null)

  const refresh = useCallback(async () => {
    setClusters(await listClusters())
    setBinaryPath(await resolveBinary())
  }, [])

  useEffect(() => {
    refresh()
    getSettings().then((s) => setSettingsBin(s.hypercluster_binary ?? ''))
  }, [refresh])

  useEffect(() => {
    if (!active) return
    const updated = clusters.find((c) => c.name === active.name)
    if (updated) setActive(updated)
  }, [clusters, active?.name])

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
      if ((e.metaKey || e.ctrlKey) && e.shiftKey && e.key.toLowerCase() === 'f') {
        e.preventDefault()
        setGlobalSearchOpen(true)
      }
      if (
        e.key === 'Escape' &&
        view === 'deploy' &&
        !running &&
        returnViewAfterJob
      ) {
        setView(returnViewAfterJob)
        setReturnViewAfterJob(null)
        returnViewRef.current = null
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [view, running, returnViewAfterJob])

  useEffect(() => {
    let u1: (() => void) | undefined
    let u2: (() => void) | undefined
    let u3: (() => void) | undefined
    ;(async () => {
      u1 = await listen<{ plain?: string; line?: string }>('hc-log-line', (ev) => {
        setLogs((prev) => [...prev, ev.payload.plain ?? ev.payload.line ?? ''])
      })
      u2 = await listen<ParsedStage>('hc-stage', (ev) => setStage(ev.payload))
      u3 = await listen<JobExitPayload>('hc-exit', async (ev) => {
        setRunning(false)
        setRunningCluster(null)
        setLastJobSuccess(ev.payload.success)
        setDetailRefreshKey((k) => k + 1)
        await refresh()
      })
    })()
    return () => {
      u1?.()
      u2?.()
      u3?.()
    }
  }, [refresh])

  const reloadNodeStats = useCallback(async (list: ClusterEntry[]) => {
    const stats: Record<string, { ready: number; total: number }> = {}
    const statuses: Record<string, StatusJson | null> = {}
    const vmsMap: Record<string, VmsJson | null> = {}
    for (const c of list) {
      try {
        const s = await statusJson(c.config_path)
        stats[c.name] = { ready: s.ready, total: s.total }
        statuses[c.name] = s
      } catch {
        statuses[c.name] = null
      }
      try {
        vmsMap[c.name] = await vmsJson(c.config_path)
      } catch {
        vmsMap[c.name] = null
      }
    }
    setNodeStats(stats)
    setStatusByCluster(statuses)
    setVmsByCluster(vmsMap)
  }, [])

  useEffect(() => {
    if (clusters.length) reloadNodeStats(clusters)
  }, [clusters, reloadNodeStats, detailRefreshKey])

  const runOn = async (
    cluster: ClusterEntry,
    command: string,
    opts?: { force?: boolean; dryRun?: boolean; args?: string[] },
    meta?: { returnView?: View | null },
  ) => {
    const { runCommand } = await import('./lib/api')
    returnViewRef.current = meta?.returnView ?? null
    setReturnViewAfterJob(meta?.returnView ?? null)
    setActive(cluster)
    setActiveCommand(
      [command, ...(opts?.args ?? [])].join(' ') + (opts?.dryRun ? ' (dry-run)' : ''),
    )
    setView('deploy')
    setLogs([])
    setStage(null)
    setRunning(true)
    setRunningCluster(cluster.name)
    setLastJobSuccess(null)
    try {
      await runCommand({
        clusterName: cluster.name,
        configPath: cluster.config_path,
        command,
        force: opts?.force,
        dryRun: opts?.dryRun,
        args: opts?.args,
      })
    } catch {
      /* hc-exit still fires; errors shown in logs + notification */
    }
  }

  const openCluster = (cluster: ClusterEntry) => {
    setActive(cluster)
    setView('cluster')
  }

  const openClusterSettings = async (cluster: ClusterEntry) => {
    await openEditStudio(cluster)
  }

  const openEditor = async (cluster: ClusterEntry, returnView: View = 'cluster') => {
    const { readClusterConf } = await import('./lib/api')
    setActive(cluster)
    setConfDraft(await readClusterConf(cluster.config_path))
    setEditorReturnView(returnView)
    setView('editor')
  }

  const saveConf = async () => {
    if (!active) return
    setConfSaving(true)
    try {
      const { writeClusterConf } = await import('./lib/api')
      await writeClusterConf(active.config_path, confDraft)
      await refresh()
      setView(editorReturnView)
      setPreflightPromptCluster(active)
    } finally {
      setConfSaving(false)
    }
  }

  const removeFromRegistry = async (cluster: ClusterEntry) => {
    const { deleteCluster } = await import('./lib/api')
    await deleteCluster(cluster.name)
    if (active?.name === cluster.name) setActive(null)
    await refresh()
    setView('dashboard')
  }

  const openStudioHub = () => {
    setStudioSpec(defaultClusterSpec())
    setStudioStep('intent')
    setStudioSavedPath(null)
    setView('studio-hub')
  }

  const startFromIntent = (intentId: StudioIntentId, mode: 'quick' | 'advanced') => {
    const intent = intentById(intentId)
    setStudioIntentId(intentId)
    setStudioSpec(applyStudioTemplate(intent.templateId))
    setStudioSavedPath(null)
    if (mode === 'quick') {
      setView('quick-deploy')
      return
    }
    setStudioExpertLevel('advanced')
    setStudioStep('intent')
    setView('studio')
  }

  const saveStudioCluster = async (): Promise<ClusterEntry | null> => {
    if (!studioSpec.clusterName.trim()) {
      window.alert('Cluster name is required.')
      return null
    }
    if (studioSpec.controlPlaneIps.length === 0 && studioSpec.nodes.length === 0) {
      window.alert('Add at least one control plane node or IP.')
      return null
    }
    setStudioSaving(true)
    try {
      let entry: ClusterEntry
      if (studioSavedPath) {
        const original = await readClusterConf(studioSavedPath)
        const merged = mergeClusterSpec(original, studioSpec)
        entry = await updateClusterByPath(
          studioSavedPath,
          merged,
          studioSpec.clusterName,
          studioSpec.k8sDistro,
        )
      } else {
        const conf = buildClusterConfFromSpec(studioSpec)
        entry = await createCluster(studioSpec.clusterName, conf, studioSpec.k8sDistro)
        setStudioSavedPath(entry.config_path)
      }
      await refresh()
      setActive(entry)
      setDetailRefreshKey((k) => k + 1)
      return entry
    } catch {
      return null
    } finally {
      setStudioSaving(false)
    }
  }

  const deployStudioCluster = async () => {
    const entry = active ?? (await saveStudioCluster())
    if (!entry) return
    await runOn(entry, 'deploy', undefined, { returnView: 'cluster' })
  }

  const cloneClusterToStudio = async (cluster: ClusterEntry) => {
    const raw = await readClusterConf(cluster.config_path)
    const parsed = parseClusterSpec(raw, cluster.name)
    parsed.clusterName = `${cluster.name}-clone`
    parsed.templateId = ''
    setStudioSpec(parsed)
    setStudioStep('nodes')
    setStudioSavedPath(null)
    setView('studio')
  }

  const openEditStudio = async (cluster: ClusterEntry) => {
    const raw = await readClusterConf(cluster.config_path)
    setActive(cluster)
    setStudioSpec(parseClusterSpec(raw, cluster.name))
    setStudioStep('intent')
    setStudioSavedPath(cluster.config_path)
    setView('studio')
  }

  const handleImportConf = async () => {
    const path = await pickClusterConf()
    if (!path) return
    const entry = await importCluster(path)
    await refresh()
    setActive(entry)
    setView('cluster')
  }

  const searchIndex = useMemo(
    () => buildSearchIndex(clusters, statusByCluster, vmsByCluster),
    [clusters, statusByCluster, vmsByCluster],
  )

  const handleSearchSelect = (result: SearchResult) => {
    if (result.kind === 'action') {
      if (result.action === 'create-hub') openStudioHub()
      else if (result.action === 'quick-virt') startFromIntent('virtualization', 'quick')
      else if (result.action === 'import-conf') handleImportConf()
      return
    }
    if (result.kind === 'cluster' || result.kind === 'node' || result.kind === 'vm') {
      openCluster(result.cluster)
    }
  }

  const handlePaletteSelect = (selection: PaletteSelection) => {
    if (selection.kind === 'app') {
      if (selection.action === 'create-hub') openStudioHub()
      else if (selection.action === 'quick-virt') startFromIntent('virtualization', 'quick')
      else if (selection.action === 'quick-gpu') startFromIntent('ai-platform', 'quick')
      else if (selection.action === 'import-conf') handleImportConf()
      return
    }
    if (selection.kind === 'detail') {
      openCluster(selection.cluster)
      return
    }
    if (selection.kind === 'edit') {
      openEditor(selection.cluster)
      return
    }
    if (selection.kind === 'settings') {
      openClusterSettings(selection.cluster)
      return
    }
    runOn(selection.cluster, selection.command, { args: selection.args }, { returnView: 'cluster' })
  }

  const nav: { id: View; label: string; disabled?: boolean }[] = [
    { id: 'dashboard', label: 'Dashboard' },
    {
      id: 'cluster',
      label: active ? active.name : 'Cluster detail',
      disabled: !active,
    },
    { id: 'studio-hub', label: 'Create Cluster' },
    { id: 'operations', label: 'Advanced ops' },
    { id: 'settings', label: 'Settings' },
  ]

  return (
    <div className="flex min-h-screen">
      <aside className="glass-panel m-3 flex w-56 flex-col gap-1 p-3">
        <AppBrandHeader />
        {nav.map((n) => (
          <button
            key={n.id}
            type="button"
            disabled={n.disabled}
            className={`rounded-xl px-3 py-2 text-left text-sm disabled:opacity-40 ${
              view === n.id ? 'bg-glass-accent/25 text-white' : 'text-glass-muted hover:bg-white/5'
            }`}
            onClick={() => {
              if (n.id === 'cluster' && active) openCluster(active)
              else if (n.id === 'studio-hub') openStudioHub()
              else if (!n.disabled) setView(n.id)
            }}
          >
            {n.label}
          </button>
        ))}
        <p className="mt-auto px-2 text-[10px] text-glass-muted">⌘K palette · Esc back from logs</p>
        <ZyvorFooter className="px-2" />
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
                <button type="button" className="btn-primary" onClick={openStudioHub}>
                  + New Cluster
                </button>
              </div>
            </div>
            {clusters.length === 0 && (
              <GlassCard className="mb-6">
                <p className="text-glass-muted">
                  No clusters in the desktop registry yet. Import an existing{' '}
                  <code className="text-white">cluster.conf</code> or create one with Cluster Studio.
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
                  runningCluster={runningCluster}
                  onOpen={() => openCluster(c)}
                  onConfigure={() => openClusterSettings(c)}
                  onDeploy={() => runOn(c, 'deploy', undefined, { returnView: 'cluster' })}
                />
              ))}
            </div>
          </div>
        )}

        {view === 'studio-hub' && (
          <CreateClusterHub
            clusters={clusters}
            onIntent={startFromIntent}
            onImport={handleImportConf}
            onClone={cloneClusterToStudio}
            onAdvancedStudio={() => {
              setStudioSpec(defaultClusterSpec())
              setStudioExpertLevel('expert')
              setStudioStep('intent')
              setStudioSavedPath(null)
              setView('studio')
            }}
            onBack={() => setView('dashboard')}
          />
        )}

        {view === 'quick-deploy' && (
          <QuickDeployStudio
            spec={studioSpec}
            intentId={studioIntentId}
            onChange={setStudioSpec}
            onSave={saveStudioCluster}
            onDeploy={deployStudioCluster}
            onBack={openStudioHub}
            onAdvanced={() => {
              setStudioExpertLevel('advanced')
              setStudioStep('nodes')
              setView('studio')
            }}
            saving={studioSaving}
          />
        )}

        {view === 'studio' && (
          <ClusterStudio
            spec={studioSpec}
            onChange={setStudioSpec}
            step={studioStep}
            onStep={setStudioStep}
            onSave={saveStudioCluster}
            onDeploy={deployStudioCluster}
            onBack={openStudioHub}
            expertLevel={studioExpertLevel}
            onExpertLevel={setStudioExpertLevel}
            saving={studioSaving}
            tempConfPath={studioSavedPath ?? active?.config_path ?? null}
          />
        )}

        {view === 'cluster' && active && (
          <ClusterDetailView
            cluster={active}
            runningCluster={runningCluster}
            refreshToken={detailRefreshKey}
            onBack={() => setView('dashboard')}
            onRun={(command, opts) =>
              runOn(active, command, opts, { returnView: 'cluster' })
            }
            onEditConf={() => openEditor(active)}
            onEditSettings={() => openEditStudio(active)}
            onEditStudio={() => openEditStudio(active)}
            onRemoveFromRegistry={() => removeFromRegistry(active)}
          />
        )}

        {view === 'editor' && active && (
          <ConfEditor
            value={confDraft}
            onChange={setConfDraft}
            onSave={saveConf}
            onCancel={() => setView(editorReturnView)}
            saving={confSaving}
            path={active.config_path}
          />
        )}

        {view === 'deploy' && active && (
          <div>
            <div className="mb-4 flex flex-wrap items-center justify-between gap-2">
              <h2 className="text-xl font-semibold">
                {active.name} — {activeCommand}
                {running ? ' (running)' : ''}
                {!running && lastJobSuccess === true && (
                  <span className="ml-2 text-sm text-emerald-300">✓ succeeded</span>
                )}
                {!running && lastJobSuccess === false && (
                  <span className="ml-2 text-sm text-red-300">✗ failed</span>
                )}
              </h2>
              {!running && returnViewAfterJob && (
                <button
                  type="button"
                  className="btn-primary text-sm"
                  onClick={() => {
                    setView(returnViewAfterJob)
                    setReturnViewAfterJob(null)
                    returnViewRef.current = null
                  }}
                >
                  Back{returnViewAfterJob === 'cluster' ? ' to cluster detail' : ''}
                </button>
              )}
            </div>
            <DeployPipeline stage={stage} running={running} />
            <DeployOpsCenter
              cluster={active}
              running={running}
              lastSuccess={lastJobSuccess}
              onRun={(command, opts) => runOn(active, command, opts, { returnView: returnViewAfterJob ?? 'cluster' })}
              onCancel={async () => {
                const { cancelRun } = await import('./lib/api')
                await cancelRun(active.name)
                setRunning(false)
                setRunningCluster(null)
              }}
            />
            {stage && (
              <GlassCard className="mb-4">
                <p className="text-sm font-medium">{stage.label}</p>
              </GlassCard>
            )}
            <StructuredLogConsole lines={logs} />
          </div>
        )}

        {view === 'operations' && (
          <div className="max-w-xl space-y-4">
            <h2 className="text-xl font-semibold">Advanced operations</h2>
            <p className="text-sm text-glass-muted">
              Common tasks live on the cluster detail view. Use this page for destructive or
              infrequent commands.
            </p>
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
                <button type="button" className="btn-ghost w-full text-left" onClick={() => setView('cluster')}>
                  ← Open cluster detail
                </button>
                <button
                  type="button"
                  className="btn-ghost w-full text-left"
                  onClick={() => runOn(active, 'deploy', { dryRun: true }, { returnView: 'operations' })}
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
                  onClick={() =>
                    runOn(active, 'remove-node', { args: [removeNode], force: true }, {
                      returnView: 'operations',
                    })
                  }
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
                  onClick={() =>
                    runOn(active, 'destroy', { force: true }, { returnView: 'operations' })
                  }
                >
                  Destroy cluster
                </button>
              </GlassCard>
            )}
          </div>
        )}

        {view === 'settings' && (
          <div className="max-w-2xl space-y-4">
            <GlassCard className="space-y-4">
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
              <button type="button" className="btn-ghost" onClick={handleImportConf}>
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
            <ClusterRegistryList
              clusters={clusters}
              runningCluster={runningCluster}
              activeName={active?.name}
              onOpen={openCluster}
            />
          </div>
        )}
      </main>

      {preflightPromptCluster && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm">
          <GlassCard className="max-w-md">
            <h3 className="mb-2 text-lg font-semibold">Config saved</h3>
            <p className="mb-4 text-sm text-glass-muted">
              Run preflight on <strong>{preflightPromptCluster.name}</strong> to validate changes?
            </p>
            <div className="flex justify-end gap-2">
              <button
                type="button"
                className="btn-ghost"
                onClick={() => setPreflightPromptCluster(null)}
              >
                Later
              </button>
              <button
                type="button"
                className="btn-primary"
                onClick={() => {
                  const c = preflightPromptCluster
                  setPreflightPromptCluster(null)
                  runOn(c, 'preflight', undefined, { returnView: editorReturnView })
                }}
              >
                Run preflight
              </button>
            </div>
          </GlassCard>
        </div>
      )}

      <GlobalSearch
        open={globalSearchOpen}
        onClose={() => setGlobalSearchOpen(false)}
        index={searchIndex}
        onSelect={handleSearchSelect}
      />

      <CommandPalette
        open={paletteOpen}
        onClose={() => setPaletteOpen(false)}
        clusters={clusters}
        onSelect={handlePaletteSelect}
      />
    </div>
  )
}
