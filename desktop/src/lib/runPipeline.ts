import type { ClusterEntry } from '../lib/types'

export type PipelineStep = {
  command: string
  args?: string[]
  label: string
}

/** End-to-end k3s: preflight → deploy (LAB_AUTO_SETUP when enabled) → test */
export const FULL_DEPLOY_PIPELINE: PipelineStep[] = [
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
  runCommand: (step: PipelineStep, index: number) => Promise<void>,
): Promise<boolean> {
  for (let i = 0; i < steps.length; i++) {
    try {
      await runCommand(steps[i], i)
    } catch {
      return false
    }
  }
  return true
}
