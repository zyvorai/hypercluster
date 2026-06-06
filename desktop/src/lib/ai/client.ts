import { invoke } from '@tauri-apps/api/core'
import type { AiChatResponse, AiContextBundle, AiMessage, AiSettings } from './types'
import { AI_SYSTEM_PROMPT } from './prompts'
import { contextToPromptBlock } from './context'

export async function aiChat(opts: {
  messages: AiMessage[]
  system?: string
  context?: AiContextBundle
  maxTokens?: number
}): Promise<AiChatResponse> {
  const systemParts = [opts.system ?? AI_SYSTEM_PROMPT]
  if (opts.context) {
    systemParts.push('\n\n---\nCluster context:\n' + contextToPromptBlock(opts.context))
  }
  return invoke('ai_chat_cmd', {
    req: {
      messages: opts.messages,
      system: systemParts.join(''),
      max_tokens: opts.maxTokens ?? 2048,
    },
  })
}

export async function aiAsk(
  question: string,
  context?: AiContextBundle,
  system?: string,
): Promise<string> {
  const res = await aiChat({
    messages: [{ role: 'user', content: question }],
    system,
    context,
  })
  return res.content
}

export function defaultAiSettings(): AiSettings {
  return {
    enabled: false,
    provider: 'openai',
    api_key: null,
    base_url: null,
    model: null,
  }
}

export function mergeAiSettings(base?: AiSettings | null): AiSettings {
  return { ...defaultAiSettings(), ...base }
}

export function providerDefaults(provider: AiSettings['provider']): {
  base_url: string
  model: string
} {
  switch (provider) {
    case 'ollama':
      return { base_url: 'http://127.0.0.1:11434/v1', model: 'llama3.2' }
    case 'anthropic':
      return { base_url: 'https://api.anthropic.com', model: 'claude-3-5-sonnet-latest' }
    default:
      return { base_url: 'https://api.openai.com/v1', model: 'gpt-4o-mini' }
  }
}

export { contextToPromptBlock }
