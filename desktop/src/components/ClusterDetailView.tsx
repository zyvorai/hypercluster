import { useCallback, useEffect, useState } from 'react'
import { preflightJson, readClusterConf, revealConfig, statusJson, testJson, vmsJson, workloadsJson, vmCreateJson } from '../lib/api'
import { parseClusterConf } from '../lib/confParse'
import { parseClusterSpec, installPlan } from '../lib/clusterSpec'
import { clusterPillStatus } from '../lib/clusterStatus'
import { summarizeClusterLive } from '../lib/clusterLive'
import type {
  ClusterEntry,
  ClusterSpec,
  CockpitSection,
  PreflightJson,
  StatusJson,
  TestJson,
  VmsJson,
  WorkloadsJson,
  WizardForm,
} from '../lib/types'
import { GlassCard } from './GlassCard'
import { ClusterLiveSnapshot } from './ClusterLiveSnapshot'
import { KubeVirtStudio } from './KubeVirtStudio'
import { StatusPill } from './StatusPill'
import { TestResultsPanel } from './TestResultsPanel'

export function ClusterDetailView({
  cluster,
  runningCluster,
  refreshToken,
  onBack,
  onRun,
  onRunFull,
  onEditConf,
  onEditSettings,
  onEditStudio,
  onRemoveFromRegistry,
}: {
  cluster: ClusterEntry
  runningCluster?: string | null
  refreshToken?: number
  onBack: () => void
  onRun: (command: string, opts?: { args?: string[]; force?: boolean }) => void
  onRunFull?: () => void
  onEditConf: () => void
  onEditSettings: () => void
  onEditStudio?: () => void
  onRemoveFromRegistry: () => void
}) {
  const [config, setConfig] = useState<WizardForm | null>(null)
  const [spec, setSpec] = useState<ClusterSpec | null>(null)
  const [section, setSection] = useState<CockpitSection>('overview')
  const [status, setStatus] = useState<StatusJson | null>(null)
  const [tests, setTests] = useState<TestJson | null>(null)
  const [preflight, setPreflight] = useState<PreflightJson | null>(null)
  const [statusErr, setStatusErr] = useState('')
  const [testErr, setTestErr] = useState('')
  const [testLoading, setTestLoading] = useState(false)
  const [preflightLoading, setPreflightLoading] = useState(false)
  const [vms, setVms] = useState<VmsJson | null>(null)
  const [vmsLoading, setVmsLoading] = useState(false)
  const [workloads, setWorkloads] = useState<WorkloadsJson | null>(null)
  const [workloadsLoading, setWorkloadsLoading] = useState(false)
  const [liveRefreshing, setLiveRefreshing] = useState(false)
  const [vmCreateMsg, setVmCreateMsg] = useState('')
  const [removeConfirm, setRemoveConfirm] = useState('')

  const loadStatus = useCallback(async () => {
    try {
      setStatus(await statusJson(cluster.config_path))
      setStatusErr('')
    } catch (e) {
      setStatusErr(String(e))
      setStatus(null)
    }
  }, [cluster.config_path])

  const loadTests = useCallback(
    async (full = false) => {
      setTestLoading(true)
      setTestErr('')
      try {
        setTests(await testJson(cluster.config_path, full))
      } catch (e) {
        setTestErr(String(e))
        setTests(null)
      } finally {
        setTestLoading(false)
      }
    },
    [cluster.config_path],
  )

  const loadPreflight = useCallback(async () => {
    setPreflightLoading(true)
    try {
      setPreflight(await preflightJson(cluster.config_path))
    } catch {
      setPreflight(null)
    } finally {
      setPreflightLoading(false)
    }
  }, [cluster.config_path])

  useEffect(() => {
    readClusterConf(cluster.config_path)
      .then((raw) => {
        setConfig(parseClusterConf(raw, cluster.name))
        setSpec(parseClusterSpec(raw, cluster.name))
      })
      .catch(() => {
        setConfig(null)
        setSpec(null)
      })
  }, [cluster.config_path, cluster.name, refreshToken])

  const loadVms = useCallback(async () => {
    setVmsLoading(true)
    try {
      setVms(await vmsJson(cluster.config_path))
    } catch {
      setVms(null)
    } finally {
      setVmsLoading(false)
    }
  }, [cluster.config_path])

  const loadWorkloads = useCallback(async () => {
    setWorkloadsLoading(true)
    try {
      setWorkloads(await workloadsJson(cluster.config_path))
    } catch {
      setWorkloads(null)
    } finally {
      setWorkloadsLoading(false)
    }
  }, [cluster.config_path])

  useEffect(() => {
    loadStatus()
    loadTests(false)
    loadPreflight()
    loadVms()
    loadWorkloads()
  }, [loadStatus, loadTests, loadPreflight, loadVms, loadWorkloads, refreshToken])

  useEffect(() => {
    if (section === 'workloads' && !workloads) loadWorkloads()
  }, [section, workloads, loadWorkloads, refreshToken])

  const refreshLive = useCallback(async () => {
    setLiveRefreshing(true)
    await Promise.all([loadStatus(), loadVms(), loadWorkloads(), loadTests(false)])
    setLiveRefreshing(false)
  }, [loadStatus, loadVms, loadWorkloads, loadTests])

  const pillStatus = clusterPillStatus(cluster, runningCluster ?? null, status)
  const liveSummary = summarizeClusterLive(status, workloads, vms)
  const sections: { id: CockpitSection; label: string }[] = [
    { id: 'overview', label: 'Overview' },
    { id: 'nodes', label: 'Nodes' },
    { id: 'workloads', label: 'Workloads' },
    { id: 'network', label: 'Networking' },
    { id: 'storage', label: 'Storage' },
    { id: 'vms', label: 'Virtual Machines' },
    { id: 'templates', label: 'Templates' },
    { id: 'gpu', label: 'GPU' },
    { id: 'platform', label: 'Platform' },
    { id: 'observability', label: 'Observability' },
    { id: 'security', label: 'Security' },
    { id: 'backups', label: 'Backups' },
    { id: 'upgrades', label: 'Upgrades' },
    { id: 'settings', label: 'Settings' },
  ]

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <button type="button" className="btn-ghost mb-2 text-sm" onClick={onBack}>
            ← Back
          </button>
          <h2 className="flex items-center gap-3 text-2xl font-semibold">
            {cluster.name}
            <StatusPill status={pillStatus} />
          </h2>
          <p className="text-sm text-glass-muted">
            {cluster.distro} · Cluster Studio cockpit
          </p>
          <button
            type="button"
            className="text-xs text-glass-accent"
            onClick={() => revealConfig(cluster.config_path)}
          >
            Reveal cluster.conf
          </button>
          {cluster.last_action && (
            <p className="text-xs text-glass-muted">
              Last: {cluster.last_action}
              {cluster.last_action_at ? ` · ${cluster.last_action_at}` : ''}
              {cluster.last_action_ok === false
                ? ' · failed'
                : cluster.last_action_ok
                  ? ' · ok'
                  : ''}
            </p>
          )}
        </div>
        <div className="flex flex-wrap gap-2">
          <button type="button" className="btn-ghost" onClick={() => void refreshLive()} disabled={liveRefreshing}>
            {liveRefreshing ? 'Refreshing…' : 'Refresh live state'}
          </button>
          <button type="button" className="btn-ghost" onClick={() => onRun('preflight')}>
            preflight
          </button>
          {onRunFull && cluster.distro === 'k3s' ? (
            <button type="button" className="btn-primary" onClick={onRunFull}>
              Deploy full stack
            </button>
          ) : (
            <button type="button" className="btn-primary" onClick={() => onRun('deploy')}>
              Deploy
            </button>
          )}
          <button type="button" className="btn-ghost" onClick={() => onRun('deploy')}>
            deploy only
          </button>
          <button type="button" className="btn-ghost" onClick={() => onRun('lab', { args: ['setup'] })}>
            lab setup
          </button>
          <button type="button" className="btn-ghost" onClick={() => onRun('test')}>
            test
          </button>
          {onEditStudio && (
            <button type="button" className="btn-primary" onClick={onEditStudio}>
              Edit in Studio
            </button>
          )}
          <button type="button" className="btn-ghost" onClick={onEditSettings}>
            Settings form
          </button>
          <button type="button" className="btn-ghost" onClick={onEditConf}>
            Raw conf
          </button>
        </div>
      </div>

      <div className="flex flex-wrap gap-1">
        {sections.map((s) => (
          <button
            key={s.id}
            type="button"
            className={`rounded-lg px-3 py-1 text-sm ${
              section === s.id ? 'bg-glass-accent/30' : 'bg-white/5 text-glass-muted'
            }`}
            onClick={() => setSection(s.id)}
          >
            {s.label}
          </button>
        ))}
      </div>

      {section === 'overview' && (
        <>
          <ClusterLiveSnapshot
            summary={liveSummary}
            workloads={workloads}
            vms={vms}
            loading={liveRefreshing || workloadsLoading || vmsLoading}
            onGoNodes={() => setSection('nodes')}
            onGoWorkloads={() => setSection('workloads')}
            onGoVms={() => setSection('vms')}
          />
          {config && (
        <GlassCard>
          <div className="mb-3 flex items-center justify-between">
            <h3 className="font-medium">Cluster configuration</h3>
            <button type="button" className="text-xs text-glass-accent" onClick={onEditSettings}>
              Edit
            </button>
          </div>
          <dl className="grid gap-2 text-sm sm:grid-cols-2">
            <div>
              <dt className="text-glass-muted">Control plane</dt>
              <dd>{config.controlPlaneIps.join(', ') || '—'}</dd>
            </div>
            <div>
              <dt className="text-glass-muted">Workers</dt>
              <dd>{config.workerIps.join(', ') || '—'}</dd>
            </div>
            <div>
              <dt className="text-glass-muted">SSH</dt>
              <dd>
                {config.sshUser}@{config.controlPlaneIps[0] || '?'} · port {config.sshPort}
              </dd>
            </div>
            <div>
              <dt className="text-glass-muted">SSH key</dt>
              <dd className="truncate">{config.sshKey || '—'}</dd>
            </div>
            {config.metallbEnabled && (
              <div className="sm:col-span-2">
                <dt className="text-glass-muted">MetalLB pool</dt>
                <dd>{config.metallbIpPool || '—'}</dd>
              </div>
            )}
          </dl>
          {config.controlPlaneIps.length === 0 && (
            <p className="mt-2 text-sm text-amber-200">
              No control plane IPs configured — add them before deploy.
            </p>
          )}
        </GlassCard>
          )}
          {tests && (
            <GlassCard>
              <div className="mb-3 flex items-center justify-between">
                <h3 className="font-medium">Platform smoke</h3>
                <span className="text-sm text-glass-muted">
                  {tests.pass} pass · {tests.fail} fail
                </span>
              </div>
              <TestResultsPanel results={tests} loading={testLoading} error={testErr} />
            </GlassCard>
          )}
        </>
      )}

      {section === 'nodes' && (
        <GlassCard>
          <div className="mb-3 flex items-center justify-between">
            <h3 className="font-medium">Nodes</h3>
            <button type="button" className="text-xs text-glass-accent" onClick={loadStatus}>
              Refresh
            </button>
          </div>
          {statusErr && <p className="text-sm text-red-300">{statusErr}</p>}
          {status && (
            <>
              <p className="mb-2 text-sm text-glass-muted">
                {status.ready}/{status.total} ready
              </p>
              <table className="w-full text-sm">
                <thead>
                  <tr className="text-left text-glass-muted">
                    <th className="pb-1">Name</th>
                    <th className="pb-1">Ready</th>
                    <th className="pb-1">Roles</th>
                  </tr>
                </thead>
                <tbody>
                  {status.nodes.map((n) => (
                    <tr key={n.name} className="border-t border-glass-border/50">
                      <td className="py-1">{n.name}</td>
                      <td className={n.ready ? 'text-emerald-300' : 'text-red-300'}>
                        {n.ready ? 'Yes' : 'No'}
                      </td>
                      <td className="text-glass-muted">{n.roles || 'worker'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </>
          )}
          {spec && spec.nodes.length > 0 && (
            <div className="mt-4 border-t border-glass-border pt-4">
              <p className="mb-2 text-xs text-glass-muted">Configured in spec</p>
              <ul className="text-sm">
                {spec.nodes.map((n) => (
                  <li key={n.id}>
                    {n.hostname} · {n.ip} · {n.roles.join(', ')}
                  </li>
                ))}
              </ul>
            </div>
          )}
        </GlassCard>
      )}

      {section === 'network' && spec && (
        <GlassCard>
          <h3 className="mb-3 font-medium">Networking</h3>
          <dl className="grid gap-2 text-sm sm:grid-cols-2">
            <div>
              <dt className="text-glass-muted">CNI</dt>
              <dd>{spec.cniPlugin}</dd>
            </div>
            <div>
              <dt className="text-glass-muted">Pod CIDR</dt>
              <dd>{spec.kubePodsSubnet}</dd>
            </div>
            <div>
              <dt className="text-glass-muted">Service CIDR</dt>
              <dd>{spec.kubeServiceAddresses}</dd>
            </div>
            <div>
              <dt className="text-glass-muted">MetalLB</dt>
              <dd>{spec.metallbEnabled ? spec.metallbIpPool || 'enabled' : 'off'}</dd>
            </div>
            <div>
              <dt className="text-glass-muted">Cilium Hubble</dt>
              <dd>{spec.ciliumHubble ? 'on' : 'off'}</dd>
            </div>
            <div>
              <dt className="text-glass-muted">Cilium BGP</dt>
              <dd>{spec.ciliumBgp ? 'on' : 'off'}</dd>
            </div>
          </dl>
        </GlassCard>
      )}

      {section === 'storage' && spec && (
        <GlassCard>
          <h3 className="mb-3 font-medium">Storage</h3>
          <p className="text-sm">
            Longhorn: {spec.longhornEnabled ? 'enabled' : 'disabled'}
          </p>
          <p className="mt-2 text-xs text-glass-muted">
            KubeVirt disks provider: {spec.kubevirtEnabled ? 'on' : 'off'}
          </p>
        </GlassCard>
      )}

      {section === 'platform' && spec && (
        <div className="grid gap-4 lg:grid-cols-2">
          <GlassCard>
            <h3 className="mb-3 font-medium">Platform stack</h3>
            <ul className="flex flex-wrap gap-1 text-sm">
              {installPlan(spec).map((item) => (
                <li key={item} className="rounded bg-white/5 px-2 py-0.5">
                  {item}
                </li>
              ))}
            </ul>
          </GlassCard>
          <GlassCard>
            <div className="mb-3 flex items-center justify-between">
              <h3 className="font-medium">Platform smoke</h3>
              <button
                type="button"
                className="text-xs text-glass-accent"
                onClick={() => loadTests(false)}
                disabled={testLoading}
              >
                Refresh
              </button>
            </div>
            <TestResultsPanel results={tests} loading={testLoading} error={testErr} />
          </GlassCard>
          <GlassCard className="lg:col-span-2">
            <div className="mb-3 flex items-center justify-between">
              <h3 className="font-medium">Preflight checks</h3>
              <button
                type="button"
                className="text-xs text-glass-accent"
                onClick={loadPreflight}
                disabled={preflightLoading}
              >
                Refresh
              </button>
            </div>
            {preflightLoading && <p className="text-sm text-glass-muted">Loading…</p>}
            {preflight && (
              <ul className="space-y-1 text-sm">
                {preflight.checks.map((c) => (
                  <li
                    key={c.name}
                    className={`rounded-lg px-2 py-1 ${c.passed ? 'bg-emerald-500/10' : 'bg-red-500/10'}`}
                  >
                    <span className={c.passed ? 'text-emerald-300' : 'text-red-300'}>
                      {c.passed ? 'PASS' : 'FAIL'}
                    </span>{' '}
                    {c.name}
                  </li>
                ))}
              </ul>
            )}
          </GlassCard>
        </div>
      )}

      {section === 'vms' && spec && (
        <KubeVirtStudio
          spec={spec}
          vms={vms}
          loading={vmsLoading}
          readOnly
          onChange={() => {}}
          onRefreshVms={loadVms}
          onCreateFromTemplate={async (templateId, name) => {
            try {
              const res = await vmCreateJson(cluster.config_path, templateId, name)
              setVmCreateMsg(res.message)
            } catch (e) {
              setVmCreateMsg(String(e))
            }
          }}
        />
      )}
      {vmCreateMsg && section === 'vms' && (
        <p className="mt-2 text-xs text-amber-200/90">{vmCreateMsg}</p>
      )}

      {section === 'templates' && vms && (
        <GlassCard>
          <h3 className="mb-3 font-medium">Image catalog</h3>
          <div className="grid gap-2 sm:grid-cols-2">
            {vms.templates.map((t) => (
              <div key={t.id} className="rounded-xl border border-glass-border p-3 text-sm">
                <p className="font-medium">{t.label}</p>
                <p className="text-xs text-glass-muted">{t.description}</p>
              </div>
            ))}
          </div>
        </GlassCard>
      )}

      {section === 'workloads' && (
        <GlassCard>
          <div className="mb-3 flex items-center justify-between">
            <h3 className="font-medium">Workloads</h3>
            <button
              type="button"
              className="text-xs text-glass-accent"
              onClick={loadWorkloads}
              disabled={workloadsLoading}
            >
              {workloadsLoading ? 'Loading…' : 'Refresh'}
            </button>
          </div>
          {workloads && workloads.pods.length === 0 && workloads.services.length === 0 ? (
            <p className="text-sm text-glass-muted">
              No pods or services found — deploy the cluster or ensure kubeconfig is available.
            </p>
          ) : workloads ? (
            <div className="space-y-4 text-sm">
              <div>
                <p className="mb-2 font-medium text-glass-muted">
                  Pods ({workloads.pods.length})
                </p>
                <ul className="max-h-48 space-y-1 overflow-y-auto">
                  {workloads.pods.slice(0, 30).map((p) => (
                    <li key={`${p.namespace}/${p.name}`} className="flex justify-between gap-2">
                      <span>
                        {p.namespace}/{p.name}
                      </span>
                      <span className="text-glass-muted">{p.phase}</span>
                    </li>
                  ))}
                </ul>
              </div>
              <div>
                <p className="mb-2 font-medium text-glass-muted">
                  Services ({workloads.services.length})
                </p>
                <ul className="max-h-32 space-y-1 overflow-y-auto">
                  {workloads.services.slice(0, 20).map((s) => (
                    <li key={`${s.namespace}/${s.name}`} className="flex justify-between gap-2">
                      <span>
                        {s.namespace}/{s.name}
                      </span>
                      <span className="text-glass-muted">{s.type}</span>
                    </li>
                  ))}
                </ul>
              </div>
            </div>
          ) : (
            <p className="text-sm text-glass-muted">Could not load workloads (kubeconfig required).</p>
          )}
        </GlassCard>
      )}

      {section === 'gpu' && spec && (
        <GlassCard>
          <h3 className="mb-2 font-medium">GPU</h3>
          <p className="text-sm">
            GPU Operator: {spec.gpuOperatorEnabled ? 'enabled' : 'disabled'} · NFD:{' '}
            {spec.nfdEnabled ? 'enabled' : 'disabled'}
          </p>
        </GlassCard>
      )}

      {section === 'observability' && (
        <GlassCard>
          <h3 className="mb-2 font-medium">Observability</h3>
          <TestResultsPanel results={tests} loading={testLoading} error={testErr} />
        </GlassCard>
      )}

      {section === 'security' && (
        <GlassCard>
          <h3 className="mb-2 font-medium">Security</h3>
          <p className="text-sm text-glass-muted">
            cert-manager: {spec?.certManagerEnabled ? 'on' : 'off'}. Kyverno, Falco, Trivy — coming
            soon.
          </p>
        </GlassCard>
      )}

      {section === 'backups' && (
        <GlassCard>
          <h3 className="mb-2 font-medium">Backups</h3>
          <p className="text-sm text-glass-muted">Velero integration — coming soon.</p>
        </GlassCard>
      )}

      {section === 'upgrades' && (
        <GlassCard className="space-y-2">
          <h3 className="font-medium">Upgrades</h3>
          <p className="text-sm text-glass-muted">Target version: {spec?.kubeVersion ?? '—'}</p>
          <button type="button" className="btn-primary text-sm" onClick={() => onRun('upgrade')}>
            Run upgrade
          </button>
          <button type="button" className="btn-ghost text-sm" onClick={() => onRun('scale')}>
            Scale cluster
          </button>
        </GlassCard>
      )}

      {section === 'settings' && (
        <GlassCard className="space-y-2">
          <h3 className="font-medium">Settings</h3>
          <button type="button" className="btn-primary text-sm" onClick={onEditSettings}>
            Open Cluster Studio
          </button>
          {onEditStudio && (
            <button type="button" className="btn-ghost text-sm" onClick={onEditStudio}>
              Edit in Studio
            </button>
          )}
          <button type="button" className="btn-ghost text-sm" onClick={onEditConf}>
            Raw cluster.conf
          </button>
        </GlassCard>
      )}

      {section === 'overview' && (
        <GlassCard>
          <div className="mb-3 flex items-center justify-between">
            <h3 className="font-medium">Quick health</h3>
            <button
              type="button"
              className="text-xs text-glass-accent"
              onClick={() => loadTests(true)}
              disabled={testLoading}
            >
              Full test
            </button>
          </div>
          <TestResultsPanel results={tests} loading={testLoading} error={testErr} />
        </GlassCard>
      )}

      <GlassCard>
        <h3 className="mb-2 font-medium text-red-300">Remove from registry</h3>
        <p className="mb-2 text-sm text-glass-muted">
          Removes this cluster from Hypercluster Desktop only. Does not destroy the remote cluster.
        </p>
        <input
          className="mb-2 w-full max-w-md rounded-xl border border-glass-border bg-black/20 px-3 py-2 text-sm"
          placeholder={`Type ${cluster.name} to confirm`}
          value={removeConfirm}
          onChange={(e) => setRemoveConfirm(e.target.value)}
        />
        <button
          type="button"
          className="rounded-xl bg-red-600/80 px-4 py-2 text-sm disabled:opacity-40"
          disabled={removeConfirm !== cluster.name}
          onClick={onRemoveFromRegistry}
        >
          Remove from registry
        </button>
      </GlassCard>
    </div>
  )
}
