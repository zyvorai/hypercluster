import type { StudioTemplateId } from './studioTypes'

export type StudioIntentId = 'kubernetes' | 'virtualization' | 'ai-platform' | 'edge'

export type StudioExpertLevel = 'basic' | 'advanced' | 'expert'

export type StudioIntent = {
  id: StudioIntentId
  label: string
  tagline: string
  description: string
  icon: string
  templateId: StudioTemplateId
  stackPreview: string[]
}

export const STUDIO_INTENTS: StudioIntent[] = [
  {
    id: 'kubernetes',
    label: 'Kubernetes',
    tagline: 'HA production clusters',
    description: 'Kubespray or k3s with Calico/Cilium, metrics, and optional ingress.',
    icon: '☸',
    templateId: 'production-ha',
    stackPreview: ['Kubespray', 'Calico', 'metrics-server'],
  },
  {
    id: 'virtualization',
    label: 'Virtualization',
    tagline: 'KubeVirt platform',
    description: 'Intent-driven stack: KubeVirt, CDI, CNAO, SSP, MetalLB, Cilium.',
    icon: '🖥',
    templateId: 'kubevirt-lab',
    stackPreview: ['k3s', 'KubeVirt', 'CDI', 'CNAO', 'SSP'],
  },
  {
    id: 'ai-platform',
    label: 'AI Platform',
    tagline: 'GPU inference & training',
    description: 'NVIDIA GPU Operator, NFD, and placeholders for vLLM / KServe.',
    icon: '⚡',
    templateId: 'gpu-cluster',
    stackPreview: ['k3s', 'GPU Operator', 'NFD'],
  },
  {
    id: 'edge',
    label: 'Edge',
    tagline: 'Lightweight remote sites',
    description: 'Minimal k3s footprint for constrained edge hardware.',
    icon: '📡',
    templateId: 'edge-cluster',
    stackPreview: ['k3s', 'Cilium', 'metrics-server'],
  },
]

export function intentById(id: StudioIntentId): StudioIntent {
  return STUDIO_INTENTS.find((i) => i.id === id) ?? STUDIO_INTENTS[0]
}

export function stepsForExpertLevel(level: StudioExpertLevel): boolean {
  return level !== 'basic'
}
