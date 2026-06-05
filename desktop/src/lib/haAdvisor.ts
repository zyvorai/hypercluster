import type { ClusterSpec, HaPreset } from './studioTypes'

export type HaRecommendation = {
  controlPlane: number
  workers: number
  preset: HaPreset
  summary: string
  vipHint?: string
  notes: string[]
}

export function recommendHa(spec: ClusterSpec): HaRecommendation {
  const nodeCount =
    spec.nodes.length || spec.controlPlaneIps.length + spec.workerIps.length || 1

  if (nodeCount === 1) {
    return {
      controlPlane: 1,
      workers: 0,
      preset: 'single',
      summary: 'Single-node lab — all roles on one server.',
      notes: ['Ideal for dev and smoke tests.'],
    }
  }

  if (nodeCount <= 3) {
    return {
      controlPlane: nodeCount,
      workers: 0,
      preset: nodeCount >= 3 ? '3' : 'custom',
      summary: `Detected ${nodeCount} nodes — stacked control plane (no dedicated workers).`,
      vipHint: 'Consider Keepalived or an external LB for API HA when using 3 CP nodes.',
      notes: ['Kubespray supports stacked etcd on control plane nodes.'],
    }
  }

  const cp = 3
  const workers = Math.max(0, nodeCount - cp)
  return {
    controlPlane: cp,
    workers,
    preset: '3',
    summary: `Detected ${nodeCount} nodes — recommended ${cp} control plane + ${workers} workers.`,
    vipHint: 'For production HA, add VIP + HAProxy or use an external load balancer for the API.',
    notes: [
      'Dedicated workers improve workload isolation.',
      'Storage and GPU nodes can be labeled after deploy.',
    ],
  }
}
