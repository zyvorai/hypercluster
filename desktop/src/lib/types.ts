export type ClusterEntry = {
  id: string
  name: string
  config_path: string
  distro: string
  created_at: string
  last_action?: string | null
  last_action_at?: string | null
}

export type AppSettings = {
  hypercluster_binary?: string | null
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

export type WizardForm = {
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
  kubevirtEnabled: boolean
  kubevirtVersion: string
  cdiVersion: string
}

export type View =
  | 'dashboard'
  | 'wizard'
  | 'deploy'
  | 'operations'
  | 'settings'
