import type { ClusterEntry } from '../types'

export type ParsedNlCommand =
  | { kind: 'run'; cluster: ClusterEntry; command: string; args?: string[] }
  | { kind: 'open'; cluster: ClusterEntry }
  | { kind: 'ai'; query: string }
  | { kind: 'unknown'; query: string }

const RUN_ALIASES: Record<string, { command: string; args?: string[] }> = {
  preflight: { command: 'preflight' },
  deploy: { command: 'deploy' },
  test: { command: 'test' },
  'full test': { command: 'test', args: ['--full'] },
  'test full': { command: 'test', args: ['--full'] },
  status: { command: 'status' },
  health: { command: 'health' },
  destroy: { command: 'destroy' },
  'deploy full': { command: 'deploy-full' },
  redeploy: { command: 'deploy-full' },
  decommission: { command: 'decommission' },
  reinstall: { command: 'reinstall' },
  'lab setup': { command: 'lab', args: ['setup'] },
  'lab tune': { command: 'lab', args: ['tune'] },
}

function findCluster(name: string, clusters: ClusterEntry[]): ClusterEntry | null {
  const n = name.toLowerCase().trim()
  return (
    clusters.find((c) => c.name.toLowerCase() === n) ??
    clusters.find((c) => c.name.toLowerCase().includes(n)) ??
    null
  )
}

export function parseNaturalLanguage(input: string, clusters: ClusterEntry[]): ParsedNlCommand {
  const q = input.trim()
  if (!q) return { kind: 'unknown', query: q }

  const lower = q.toLowerCase()

  if (/^(ask|ai|copilot|help me|explain|why|how|what|analyze|summarize|review)\b/i.test(lower)) {
    return { kind: 'ai', query: q }
  }

  const openMatch = lower.match(/^(?:open|show|go to|view)\s+(?:cluster\s+)?(.+)$/i)
  if (openMatch) {
    const c = findCluster(openMatch[1], clusters)
    if (c) return { kind: 'open', cluster: c }
  }

  for (const [alias, cmd] of Object.entries(RUN_ALIASES)) {
    const patterns = [
      new RegExp(`^(?:run\\s+)?${alias.replace(/\s+/g, '\\s+')}\\s+(?:on\\s+)?(.+)$`, 'i'),
      new RegExp(`^(.+?)\\s+(?:→|->|\\||,)\\s*${alias.replace(/\s+/g, '\\s+')}$`, 'i'),
    ]
    for (const re of patterns) {
      const m = lower.match(re)
      if (m) {
        const c = findCluster(m[1], clusters)
        if (c) {
          return {
            kind: 'run',
            cluster: c,
            command: cmd.command,
            args: cmd.args,
          }
        }
      }
    }
  }

  if (clusters.length === 1) {
    for (const [alias, cmd] of Object.entries(RUN_ALIASES)) {
      if (lower === alias || lower === `run ${alias}`) {
        return {
          kind: 'run',
          cluster: clusters[0],
          command: cmd.command,
          args: cmd.args,
        }
      }
    }
  }

  return { kind: 'ai', query: q }
}

export function nlCommandHint(): string {
  return 'Try: "deploy k3s-175", "open mycluster", "explain health", "run test on lab"'
}
