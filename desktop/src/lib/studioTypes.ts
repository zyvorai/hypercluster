export type K8sDistro = 'k3s' | 'kubespray' | 'kubeadm' | 'rke2' | 'talos' | 'microk8s'

export type DeployModel = 'ssh' | 'talos' | 'join_token'

export type NodeRole = 'control-plane' | 'worker' | 'etcd'

export type ClusterNode = {
  id: string
  hostname: string
  ip: string
  roles: NodeRole[]
  sshUser?: string
  sshPort?: number
  sshKey?: string
  labels?: Record<string, string>
  gpu?: boolean
  storage?: boolean
  position?: { x: number; y: number }
}

export type StudioTemplateId =
  | ''
  | 'kubevirt-lab'
  | 'single-node-lab'
  | 'production-ha'
  | 'edge-cluster'
  | 'gpu-cluster'
  | 'airgap-stub'

export type HaPreset = 'single' | '3' | '5' | 'custom'

export type ClusterSpec = {
  templateId: StudioTemplateId
  clusterName: string
  environment: string
  description: string
  k8sDistro: K8sDistro
  deployModel: DeployModel
  kubesprayVersion: string
  kubeVersion: string
  nodes: ClusterNode[]
  controlPlaneIps: string[]
  workerIps: string[]
  sshUser: string
  sshKey: string
  sshPort: number
  sshProxyJump: string
  kubePodsSubnet: string
  kubeServiceAddresses: string
  cniPlugin: string
  containerManager: string
  ciliumHubble: boolean
  ciliumKubeProxyReplacement: boolean
  ciliumBgp: boolean
  ciliumWireguard: boolean
  ciliumGatewayApi: boolean
  platformStackEnabled: boolean
  metallbEnabled: boolean
  metallbIpPool: string
  certManagerEnabled: boolean
  metricsServerEnabled: boolean
  kubevirtEnabled: boolean
  cnaoEnabled: boolean
  sspEnabled: boolean
  longhornEnabled: boolean
  gpuOperatorEnabled: boolean
  nfdEnabled: boolean
  ingressNginxEnabled: boolean
  kubevirtVersion: string
  cdiVersion: string
  haControlPlane: HaPreset
  /** Secondary block device for KubeVirt PVCs (LAB_SECONDARY_DISK) */
  labSecondaryDisk: string
  labKubevirtVolumeMount: string
  labKubevirtStorageClass: string
  labStorageFormat: boolean
  labMemoryTuneEnabled: boolean
  labAutoSetup: boolean
}

export type DistroCapability = {
  id: K8sDistro
  label: string
  deployReady: boolean
  note?: string
}

export type DiscoverNode = {
  name: string
  ip: string
  source: string
  labels?: Record<string, string>
  gpu?: boolean
  vcpu?: number
  memoryMb?: number
  storageGb?: number
  virtualization?: boolean
  nicCount?: number
  numa?: boolean
}

export type DiscoverValidation = {
  ip: string
  checks: { name: string; passed: boolean; detail?: string }[]
}

export type DiscoverJson = {
  nodes: DiscoverNode[]
  validations?: DiscoverValidation[]
}

export type KubeVirtTemplate = {
  id: string
  label: string
  os: string
  description?: string
  preview?: boolean
  defaultCpu?: number
  defaultMemoryGb?: number
}

export type VmsJson = {
  vms: { name: string; namespace: string; phase: string; node: string; ip: string }[]
  templates: KubeVirtTemplate[]
}

export type WorkloadsJson = {
  pods: {
    namespace: string
    name: string
    phase: string
    node: string
    ready: number
    containers: number
  }[]
  services: { namespace: string; name: string; type: string; clusterIp: string }[]
}

export type LogFilter = 'all' | 'errors' | 'warnings' | 'progress'

export type CockpitSection =
  | 'overview'
  | 'nodes'
  | 'workloads'
  | 'network'
  | 'storage'
  | 'platform'
  | 'vms'
  | 'templates'
  | 'gpu'
  | 'security'
  | 'observability'
  | 'backups'
  | 'upgrades'
  | 'extensions'
  | 'settings'

export type StudioStep =
  | 'hub'
  | 'intent'
  | 'distro'
  | 'nodes'
  | 'network'
  | 'platform'
  | 'validate'
  | 'plan'

export type StudioIntentId = 'kubernetes' | 'virtualization' | 'ai-platform' | 'edge'

export type StudioExpertLevel = 'basic' | 'advanced' | 'expert'
