export type AiProvider = 'openai' | 'ollama' | 'anthropic'

export type AiSettings = {
  enabled?: boolean
  provider?: AiProvider
  api_key?: string | null
  base_url?: string | null
  model?: string | null
}

export type AiMessage = {
  role: 'user' | 'assistant' | 'system'
  content: string
}

export type AiChatResponse = {
  content: string
  provider: string
  model: string
}

export type AiInsightSeverity = 'info' | 'warn' | 'critical'

export type AiInsightCategory =
  | 'health'
  | 'security'
  | 'ops'
  | 'performance'
  | 'config'
  | 'cost'

export type AiInsightAction = {
  label: string
  command?: string
  args?: string[]
  prompt?: string
}

export type AiInsight = {
  id: string
  clusterName?: string
  severity: AiInsightSeverity
  category: AiInsightCategory
  title: string
  detail: string
  action?: AiInsightAction
}

export type AiContextBundle = {
  clusterName?: string
  distro?: string
  configPath?: string
  healthJson?: string
  testJson?: string
  preflightJson?: string
  recentLogs?: string
  specSummary?: string
}

export type AiQuickPrompt = {
  id: string
  label: string
  prompt: string
  icon?: string
}
