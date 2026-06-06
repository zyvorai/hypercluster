import type { ClusterEntry } from './types'

export type PipelineStep = {
  command: string
  args?: string[]
  label: string
  force?: boolean
}

/** End-to-end k3s: preflight → deploy (LAB_AUTO_SETUP when enabled) → test */
export const FULL_DEPLOY_PIPELINE: PipelineStep[] = [
  { command: 'preflight', label: 'preflight' },
  { command: 'deploy', label: 'deploy' },
  { command: 'test', label: 'test' },
]

/** Tear down remote cluster (k3s uninstall or Kubespray reset). */
export const DECOMMISSION_PIPELINE: PipelineStep[] = [
  { command: 'destroy', label: 'destroy', force: true },
]

/** Destroy then full redeploy — use when reinstalling a provisioned cluster. */
export const REINSTALL_PIPELINE: PipelineStep[] = [
  { command: 'destroy', label: 'destroy', force: true },
  { command: 'preflight', label: 'preflight' },
  { command: 'deploy', label: 'deploy' },
  { command: 'test', label: 'test' },
]

export function pipelineLabel(steps: PipelineStep[]): string {
  return steps.map((s) => s.label).join(' → ')
}

export async function executePipeline(
  _cluster: ClusterEntry,
  steps: PipelineStep[],
  runStep: (step: PipelineStep, index: number) => Promise<void>,
): Promise<boolean> {
  for (let i = 0; i < steps.length; i++) {
    try {
      await runStep(steps[i], i)
    } catch {
      return false
    }
  }
  return true
}
