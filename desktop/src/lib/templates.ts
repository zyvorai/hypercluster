import type { ClusterSpec, StudioTemplateId } from './types'
import { defaultClusterSpec } from './clusterSpec'

export type StudioTemplate = {
  id: StudioTemplateId
  label: string
  description: string
  intent: string
  icon: string
  defaults: Partial<ClusterSpec>
}

export const STUDIO_TEMPLATES: StudioTemplate[] = [
  {
    id: 'kubevirt-lab',
    label: 'KubeVirt Lab',
    description: 'Virtualization platform with KubeVirt, CDI, SSP, and CNAO on k3s.',
    intent: 'Virtualization Platform',
    icon: 'virt',
    defaults: {
      templateId: 'kubevirt-lab',
      clusterName: 'kubevirt-lab',
      k8sDistro: 'k3s',
      kubevirtEnabled: true,
      cnaoEnabled: true,
      sspEnabled: true,
      certManagerEnabled: true,
      metricsServerEnabled: true,
      metallbEnabled: true,
      metallbIpPool: '192.168.1.240-192.168.1.250',
      controlPlaneIps: ['10.0.0.10'],
      labSecondaryDisk: '/dev/sdb',
      labMemoryTuneEnabled: true,
      labAutoSetup: true,
    },
  },
  {
    id: 'single-node-lab',
    label: 'Single Node Lab',
    description: 'Minimal k3s platform stack for learning and smoke tests.',
    intent: 'Single Node Lab',
    icon: 'node',
    defaults: {
      templateId: 'single-node-lab',
      clusterName: 'single-node',
      k8sDistro: 'k3s',
      kubevirtEnabled: false,
      cnaoEnabled: false,
      sspEnabled: false,
      metallbEnabled: false,
      controlPlaneIps: ['192.168.1.10'],
    },
  },
  {
    id: 'production-ha',
    label: 'Production HA',
    description: 'Kubespray 3-node control plane with Calico CNI.',
    intent: 'HA Production Cluster',
    icon: 'ha',
    defaults: {
      templateId: 'production-ha',
      clusterName: 'production-ha',
      k8sDistro: 'kubespray',
      kubeVersion: 'v1.30.4',
      cniPlugin: 'calico',
      containerManager: 'containerd',
      kubePodsSubnet: '10.233.64.0/18',
      kubeServiceAddresses: '10.233.0.0/18',
      controlPlaneIps: ['10.0.0.11', '10.0.0.12', '10.0.0.13'],
      workerIps: ['10.0.0.21', '10.0.0.22'],
      haControlPlane: '3',
      kubevirtEnabled: false,
      metallbEnabled: false,
      platformStackEnabled: false,
    },
  },
  {
    id: 'edge-cluster',
    label: 'Edge Cluster',
    description: 'Lightweight k3s for remote edge sites.',
    intent: 'Edge Cluster',
    icon: 'edge',
    defaults: {
      templateId: 'edge-cluster',
      clusterName: 'edge',
      k8sDistro: 'k3s',
      kubevirtEnabled: false,
      longhornEnabled: false,
      metricsServerEnabled: true,
      controlPlaneIps: ['10.0.0.50'],
    },
  },
  {
    id: 'gpu-cluster',
    label: 'AI / GPU Cluster',
    description: 'k3s with NVIDIA GPU Operator and Node Feature Discovery.',
    intent: 'AI/GPU Cluster',
    icon: 'gpu',
    defaults: {
      templateId: 'gpu-cluster',
      clusterName: 'gpu-cluster',
      k8sDistro: 'k3s',
      gpuOperatorEnabled: true,
      nfdEnabled: true,
      kubevirtEnabled: false,
      controlPlaneIps: ['10.0.0.30'],
    },
  },
  {
    id: 'airgap-stub',
    label: 'Air-Gapped (preview)',
    description: 'Flags for offline mirror workflow — deploy adapter coming soon.',
    intent: 'Air-Gapped Cluster',
    icon: 'lock',
    defaults: {
      templateId: 'airgap-stub',
      clusterName: 'airgap',
      k8sDistro: 'k3s',
      controlPlaneIps: ['10.0.0.100'],
    },
  },
]

export function applyStudioTemplate(id: StudioTemplateId): ClusterSpec {
  const tpl = STUDIO_TEMPLATES.find((t) => t.id === id)
  if (!tpl) return defaultClusterSpec()
  return { ...defaultClusterSpec(), ...tpl.defaults, templateId: id }
}
