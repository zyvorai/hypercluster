import { invoke } from '@tauri-apps/api/core'
import type {
  AppSettings,
  ClusterEntry,
  ClusterSpec,
  DiscoverJson,
  VmsJson,
  WorkloadsJson,
  K8sDistro,
  PreflightJson,
  StatusJson,
  TestJson,
  HealthJson,
  WizardForm,
  WizardProfileId,
} from './types'
import { specToClusterConf, defaultClusterSpec } from './clusterSpec'

export async function listClusters(): Promise<ClusterEntry[]> {
  return invoke('list_clusters')
}

export async function getSettings(): Promise<AppSettings> {
  return invoke('get_settings')
}

export async function setSettings(settings: AppSettings): Promise<void> {
  return invoke('set_settings', { settings })
}

export async function importCluster(path: string): Promise<ClusterEntry> {
  return invoke('import_cluster_cmd', { path })
}

export async function discoverClusters(): Promise<import('./types').DiscoveredCluster[]> {
  return invoke('discover_clusters_cmd')
}

export async function autoImportDiscovered(): Promise<ClusterEntry[]> {
  return invoke('auto_import_discovered_cmd')
}

export async function runCommandBlocking(req: {
  clusterName: string
  configPath: string
  command: string
  args?: string[]
  force?: boolean
  verbose?: boolean
  dryRun?: boolean
}): Promise<void> {
  return invoke('run_hypercluster_blocking_cmd', {
    req: {
      cluster_name: req.clusterName,
      config_path: req.configPath,
      command: req.command,
      args: req.args ?? [],
      force: req.force ?? false,
      verbose: req.verbose ?? false,
      dry_run: req.dryRun ?? false,
    },
  })
}

export async function pickClusterConf(): Promise<string | null> {
  return invoke('pick_cluster_conf')
}

export async function resolveBinary(): Promise<string> {
  return invoke('resolve_hypercluster_binary')
}

export async function createCluster(
  name: string,
  confContent: string,
  distro: string,
): Promise<ClusterEntry> {
  return invoke('create_cluster_cmd', { name, confContent, distro })
}

export async function updateClusterByPath(
  configPath: string,
  confContent: string,
  name: string,
  distro: string,
): Promise<ClusterEntry> {
  return invoke('update_cluster_by_path_cmd', { configPath, confContent, name, distro })
}

export async function pickSshKey(): Promise<string | null> {
  return invoke('pick_ssh_key')
}

export async function runCommand(req: {
  clusterName: string
  configPath: string
  command: string
  args?: string[]
  force?: boolean
  verbose?: boolean
  dryRun?: boolean
}): Promise<void> {
  return invoke('run_hypercluster_cmd', {
    req: {
      cluster_name: req.clusterName,
      config_path: req.configPath,
      command: req.command,
      args: req.args ?? [],
      force: req.force ?? false,
      verbose: req.verbose ?? false,
      dry_run: req.dryRun ?? false,
    },
  })
}

export async function cancelRun(clusterName: string): Promise<void> {
  return invoke('cancel_run_cmd', { clusterName })
}

export async function healthJson(configPath: string, withTest = false): Promise<HealthJson> {
  const raw = await invoke<string>('hc_health_json', { configPath, withTest })
  return JSON.parse(raw)
}

export async function statusJson(configPath: string): Promise<StatusJson> {
  const raw = await invoke<string>('hc_status_json', { configPath })
  return JSON.parse(raw)
}

export async function testJson(configPath: string, full = false): Promise<TestJson> {
  const raw = await invoke<string>('hc_test_json', { configPath, full })
  return JSON.parse(raw)
}

export async function preflightJson(configPath: string): Promise<PreflightJson> {
  const raw = await invoke<string>('hc_preflight_json', { configPath })
  return JSON.parse(raw)
}

export async function readClusterConf(path: string): Promise<string> {
  return invoke('read_cluster_conf_cmd', { path })
}

export async function writeClusterConf(path: string, content: string): Promise<void> {
  return invoke('write_cluster_conf_cmd', { path, content })
}

export async function deleteCluster(name: string): Promise<void> {
  return invoke('delete_cluster_cmd', { name })
}

export async function openDataDir(): Promise<void> {
  return invoke('open_data_dir')
}

export async function revealConfig(configPath: string): Promise<void> {
  return invoke('reveal_config', { configPath })
}

export async function discoverJson(opts: {
  source: string
  uri?: string
  host?: string
  cidr?: string
  csv?: string
  validate?: boolean
  probe?: boolean
  sshUser?: string
  sshKey?: string
  sshPort?: number
}): Promise<DiscoverJson> {
  const raw = await invoke<string>('hc_discover_json', {
    source: opts.source,
    uri: opts.uri ?? null,
    host: opts.host ?? null,
    cidr: opts.cidr ?? null,
    csv: opts.csv ?? null,
    validate: opts.validate ?? null,
    probe: opts.probe ?? null,
    ssh_user: opts.sshUser ?? null,
    ssh_key: opts.sshKey ?? null,
    ssh_port: opts.sshPort ?? null,
  })
  return JSON.parse(raw)
}

export async function vmsJson(configPath: string): Promise<VmsJson> {
  const raw = await invoke<string>('hc_vms_json', { configPath })
  return JSON.parse(raw)
}

export async function workloadsJson(configPath: string): Promise<WorkloadsJson> {
  const raw = await invoke<string>('hc_workloads_json', { configPath })
  return JSON.parse(raw)
}

export async function vmCreateJson(
  configPath: string,
  template: string,
  name: string,
  namespace = 'default',
): Promise<{ status: string; message: string }> {
  const raw = await invoke<string>('hc_vm_create_json', {
    configPath,
    template,
    name,
    namespace,
  })
  return JSON.parse(raw)
}

export function wizardToSpec(form: WizardForm): ClusterSpec {
  const base = defaultClusterSpec()
  return {
    ...base,
    clusterName: form.clusterName,
    k8sDistro: form.k8sDistro as K8sDistro,
    kubesprayVersion: form.kubesprayVersion,
    kubeVersion: form.kubeVersion,
    controlPlaneIps: form.controlPlaneIps,
    workerIps: form.workerIps,
    sshUser: form.sshUser,
    sshKey: form.sshKey,
    sshPort: form.sshPort,
    kubePodsSubnet: form.kubePodsSubnet,
    kubeServiceAddresses: form.kubeServiceAddresses,
    cniPlugin: form.cniPlugin,
    containerManager: form.containerManager,
    metallbEnabled: form.metallbEnabled,
    metallbIpPool: form.metallbIpPool,
    longhornEnabled: form.longhornEnabled,
    kubevirtEnabled: form.kubevirtEnabled,
    certManagerEnabled: form.certManagerEnabled,
    metricsServerEnabled: form.metricsServerEnabled,
    cnaoEnabled: form.cnaoEnabled,
    sspEnabled: form.sspEnabled,
    kubevirtVersion: form.kubevirtVersion,
    cdiVersion: form.cdiVersion,
  }
}

export function buildClusterConf(form: WizardForm): string {
  return specToClusterConf(wizardToSpec(form))
}

export function buildClusterConfFromSpec(spec: ClusterSpec): string {
  return specToClusterConf(spec)
}

export const WIZARD_PROFILE_LABELS: Record<WizardProfileId, string> = {
  '': 'Blank (defaults)',
  'k3s-remote': 'k3s remote platform',
  'kubespray-ha': 'Kubespray HA',
}

export function applyWizardProfile(profile: WizardProfileId): WizardForm {
  const base = defaultWizard()
  if (profile === 'k3s-remote') {
    return {
      ...base,
      profile,
      clusterName: 'k3s-remote',
      k8sDistro: 'k3s',
      controlPlaneIps: ['10.0.0.10'],
      workerIps: [],
      sshUser: 'ubuntu',
      sshKey: '$HOME/.ssh/id_ed25519',
      metallbIpPool: '192.168.1.240-192.168.1.250',
      kubevirtEnabled: true,
      longhornEnabled: false,
    }
  }
  if (profile === 'kubespray-ha') {
    return {
      ...base,
      profile,
      clusterName: 'kubespray-ha',
      k8sDistro: 'kubespray',
      kubeVersion: 'v1.30.4',
      cniPlugin: 'calico',
      containerManager: 'containerd',
      kubePodsSubnet: '10.233.64.0/18',
      kubeServiceAddresses: '10.233.0.0/18',
      controlPlaneIps: ['10.0.0.11', '10.0.0.12', '10.0.0.13'],
      workerIps: ['10.0.0.21', '10.0.0.22'],
      sshUser: 'ubuntu',
      sshKey: '$HOME/.ssh/id_ed25519',
      metallbEnabled: false,
      kubevirtEnabled: false,
      certManagerEnabled: false,
      metricsServerEnabled: false,
      cnaoEnabled: false,
      sspEnabled: false,
    }
  }
  return { ...base, profile: '' }
}

export const defaultWizard = (): WizardForm => ({
  profile: '',
  clusterName: 'mycluster',
  k8sDistro: 'k3s',
  kubesprayVersion: 'v2.30.0',
  kubeVersion: 'v1.35.5',
  controlPlaneIps: ['10.0.0.10'],
  workerIps: [],
  sshUser: 'ubuntu',
  sshKey: '$HOME/.ssh/id_ed25519',
  sshPort: 22,
  kubePodsSubnet: '10.42.0.0/16',
  kubeServiceAddresses: '10.43.0.0/16',
  cniPlugin: 'cilium',
  containerManager: 'podman',
  metallbEnabled: true,
  metallbIpPool: '192.168.1.240-192.168.1.250',
  longhornEnabled: false,
  kubevirtEnabled: true,
  certManagerEnabled: true,
  metricsServerEnabled: true,
  cnaoEnabled: true,
  sspEnabled: true,
  kubevirtVersion: 'v1.8.3',
  cdiVersion: 'v1.65.0',
})
