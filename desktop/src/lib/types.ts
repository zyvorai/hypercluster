import type { VmsJson, WorkloadsJson } from './studioTypes'

export type ClusterEntry = {
  id: string
  name: string
  config_path: string
  distro: string
  created_at: string
  last_action?: string | null
  last_action_at?: string | null
  last_action_ok?: boolean | null
}

export type DiscoveredCluster = {
  path: string
  name: string
  distro: string
  registered: boolean
}

export type JobExitPayload = {
  cluster: string
  exitCode: number | null
  command: string
  success: boolean
}

export type AppSettings = {
  hypercluster_binary?: string | null
  ai?: import('./ai/types').AiSettings
}

export type ParsedStage = {
  current: number
  total: number
  label: string
}

export type StatusJson = {
  ready: number
  total: number
  nodes: { name: string; ready: boolean; roles: string }[]
}

export type TestJson = {
  pass: number
  fail: number
  checks: { name: string; passed: boolean }[]
}

export type WizardProfileId = '' | 'k3s-remote' | 'kubespray-ha'

export type WizardForm = {
  profile: WizardProfileId
  clusterName: string
  k8sDistro: 'k3s' | 'kubespray'
  kubesprayVersion: string
  kubeVersion: string
  controlPlaneIps: string[]
  workerIps: string[]
  sshUser: string
  sshKey: string
  sshPort: number
  kubePodsSubnet: string
  kubeServiceAddresses: string
  cniPlugin: string
  containerManager: string
  metallbEnabled: boolean
  metallbIpPool: string
  longhornEnabled: boolean
  kubevirtEnabled: boolean
  certManagerEnabled: boolean
  metricsServerEnabled: boolean
  cnaoEnabled: boolean
  sspEnabled: boolean
  kubevirtVersion: string
  cdiVersion: string
}

export type PreflightJson = {
  ok: boolean
  checks: { name: string; passed: boolean; detail?: string }[]
}

export type HealthState = 'healthy' | 'degraded' | 'unreachable' | 'unknown'

export type HealthJson = {
  cluster: string
  connected: boolean
  state: HealthState
  kubeconfig: string
  issues: string[]
  status: StatusJson
  workloads: WorkloadsJson
  vms: VmsJson
  summary: {
    nodes_ready: number
    nodes_total: number
    pods_running: number
    pods_total: number
    pods_pending: number
    pods_failed: number
    services: number
    vms_running: number
    vms_total: number
  }
  tests: TestJson | null
}

export type View =
  | 'dashboard'
  | 'cluster'
  | 'editor'
  | 'studio'
  | 'studio-hub'
  | 'quick-deploy'
  | 'wizard'
  | 'deploy'
  | 'operations'
  | 'settings'

export type {
  K8sDistro,
  DeployModel,
  NodeRole,
  ClusterNode,
  StudioTemplateId,
  HaPreset,
  ClusterSpec,
  DistroCapability,
  DiscoverNode,
  DiscoverJson,
  DiscoverValidation,
  KubeVirtTemplate,
  VmsJson,
  WorkloadsJson,
  LogFilter,
  CockpitSection,
  StudioStep,
  StudioIntentId,
  StudioExpertLevel,
} from './studioTypes'
