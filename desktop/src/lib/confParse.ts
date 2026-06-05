import type { WizardForm } from './types'
import { defaultWizard } from './api'

function stripQuotes(v: string): string {
  return v.trim().replace(/^["']|["']$/g, '')
}

export function getConfVar(content: string, key: string): string {
  const re = new RegExp(`^${key}=(.*)$`, 'm')
  const m = content.match(re)
  if (!m) return ''
  return stripQuotes(m[1])
}

export function getConfBool(content: string, key: string, fallback: boolean): boolean {
  const v = getConfVar(content, key)
  if (!v) return fallback
  return v === 'true'
}

export function getConfIps(content: string, key: string): string[] {
  return getConfVar(content, key)
    .split(/\s+/)
    .map((s) => s.trim())
    .filter(Boolean)
}

export function parseClusterConf(content: string, clusterName?: string): WizardForm {
  const base = defaultWizard()
  const distro = (getConfVar(content, 'K8S_DISTRO') || 'k3s') as 'k3s' | 'kubespray'
  const k3sVer = getConfVar(content, 'K3S_VERSION')
  const kubeVer = getConfVar(content, 'KUBE_VERSION')
  const sshPortRaw = getConfVar(content, 'SSH_PORT')

  return {
    ...base,
    profile: '',
    clusterName: getConfVar(content, 'CLUSTER_NAME') || clusterName || base.clusterName,
    k8sDistro: distro,
    kubesprayVersion: getConfVar(content, 'KUBESPRAY_VERSION') || base.kubesprayVersion,
    kubeVersion: k3sVer || kubeVer || base.kubeVersion,
    controlPlaneIps: getConfIps(content, 'CONTROL_PLANE_IPS'),
    workerIps: getConfIps(content, 'WORKER_IPS'),
    sshUser: getConfVar(content, 'SSH_USER') || base.sshUser,
    sshKey: getConfVar(content, 'SSH_KEY') || base.sshKey,
    sshPort: sshPortRaw ? Number.parseInt(sshPortRaw, 10) || base.sshPort : base.sshPort,
    kubePodsSubnet: getConfVar(content, 'KUBE_PODS_SUBNET') || base.kubePodsSubnet,
    kubeServiceAddresses: getConfVar(content, 'KUBE_SERVICE_ADDRESSES') || base.kubeServiceAddresses,
    cniPlugin: getConfVar(content, 'CNI_PLUGIN') || base.cniPlugin,
    containerManager: getConfVar(content, 'CONTAINER_MANAGER') || base.containerManager,
    metallbEnabled: getConfBool(content, 'METALLB_ENABLED', base.metallbEnabled),
    metallbIpPool: getConfVar(content, 'METALLB_IP_POOL') || base.metallbIpPool,
    longhornEnabled: getConfBool(content, 'LONGHORN_ENABLED', base.longhornEnabled),
    kubevirtEnabled: getConfBool(content, 'KUBEVIRT_ENABLED', base.kubevirtEnabled),
    certManagerEnabled: getConfBool(content, 'CERT_MANAGER_ENABLED', base.certManagerEnabled),
    metricsServerEnabled: getConfBool(content, 'METRICS_SERVER_ENABLED', base.metricsServerEnabled),
    cnaoEnabled: getConfBool(content, 'CNAO_ENABLED', base.cnaoEnabled),
    sspEnabled: getConfBool(content, 'SSP_ENABLED', base.sspEnabled),
    kubevirtVersion: getConfVar(content, 'KUBEVIRT_VERSION') || base.kubevirtVersion,
    cdiVersion: getConfVar(content, 'CDI_VERSION') || base.cdiVersion,
  }
}

function formatVar(key: string, value: string | number | boolean): string {
  if (typeof value === 'boolean') return `${key}="${value ? 'true' : 'false'}"`
  if (typeof value === 'number') return `${key}=${value}`
  return `${key}="${value}"`
}

function upsertVar(content: string, key: string, value: string | number | boolean): string {
  const line = formatVar(key, value)
  const re = new RegExp(`^${key}=.*$`, 'm')
  if (re.test(content)) return content.replace(re, line)
  return `${content.replace(/\s*$/, '')}\n${line}\n`
}

/** Merge form fields into an existing cluster.conf, preserving comments and other keys. */
export function mergeClusterConf(original: string, form: WizardForm): string {
  let out = original
  const set = (key: string, value: string | number | boolean) => {
    out = upsertVar(out, key, value)
  }

  set('CLUSTER_NAME', form.clusterName)
  set('K8S_DISTRO', form.k8sDistro)
  set('CONTROL_PLANE_IPS', form.controlPlaneIps.join(' '))
  set('WORKER_IPS', form.workerIps.join(' '))
  set('SSH_USER', form.sshUser)
  set('SSH_KEY', form.sshKey)
  set('SSH_PORT', form.sshPort)
  set('KUBE_PODS_SUBNET', form.kubePodsSubnet)
  set('KUBE_SERVICE_ADDRESSES', form.kubeServiceAddresses)
  set('CNI_PLUGIN', form.cniPlugin)
  set('CONTAINER_MANAGER', form.containerManager)
  set('METALLB_ENABLED', form.metallbEnabled)
  set('METALLB_IP_POOL', form.metallbIpPool)
  set('CERT_MANAGER_ENABLED', form.certManagerEnabled)
  set('METRICS_SERVER_ENABLED', form.metricsServerEnabled)
  set('KUBEVIRT_ENABLED', form.kubevirtEnabled)
  set('CNAO_ENABLED', form.cnaoEnabled)
  set('SSP_ENABLED', form.sspEnabled)
  set('LONGHORN_ENABLED', form.longhornEnabled)
  set('KUBEVIRT_VERSION', form.kubevirtVersion)
  set('CDI_VERSION', form.cdiVersion)

  if (form.k8sDistro === 'k3s') {
    set('K3S_VERSION', form.kubeVersion)
  } else {
    set('KUBE_VERSION', form.kubeVersion)
    set('KUBESPRAY_VERSION', form.kubesprayVersion)
  }

  return out
}
