import type { K8sDistro, DistroCapability } from './studioTypes'

export const DISTRO_CAPABILITIES: DistroCapability[] = [
  { id: 'k3s', label: 'k3s', deployReady: true },
  { id: 'kubespray', label: 'Kubespray', deployReady: true },
  { id: 'kubeadm', label: 'kubeadm (via Kubespray)', deployReady: true, note: 'Uses Kubespray Ansible path' },
  { id: 'rke2', label: 'RKE2', deployReady: false, note: 'Preview — scripts exist, not smoke-tested' },
  { id: 'talos', label: 'Talos', deployReady: false, note: 'Preview — machine config apply' },
  { id: 'microk8s', label: 'MicroK8s', deployReady: false, note: 'Preview — snap over SSH' },
]

export function isDistroDeployReady(distro: K8sDistro): boolean {
  return DISTRO_CAPABILITIES.find((d) => d.id === distro)?.deployReady ?? false
}
