import type { ClusterEntry } from './types'
import type { PipelineStep } from './runPipeline'
import { pipelineLabel } from './runPipeline'
import { runCommandBlocking } from './api'

export async function runClusterPipeline(
  cluster: ClusterEntry,
  steps: PipelineStep[],
  hooks: {
    onStart: (label: string) => void
    onStepStart: (step: PipelineStep, index: number, label: string) => void
    onStepSeparator?: (step: PipelineStep) => void
  },
): Promise<boolean> {
  hooks.onStart(pipelineLabel(steps))
  for (let i = 0; i < steps.length; i++) {
    const step = steps[i]
    hooks.onStepStart(
      step,
      i,
      i === 0 ? pipelineLabel(steps) : `${pipelineLabel(steps)} · ${step.label}`,
    )
    if (i > 0) hooks.onStepSeparator?.(step)
    try {
      await runCommandBlocking({
        clusterName: cluster.name,
        configPath: cluster.config_path,
        command: step.command,
        args: step.args,
        force: step.force,
      })
    } catch {
      return false
    }
  }
  return true
}
