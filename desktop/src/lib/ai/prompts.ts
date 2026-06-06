export const AI_SYSTEM_PROMPT = `You are Zyvor AI Copilot for Hypercluster Desktop — an expert on k3s platform stacks, Kubespray, Cilium, KubeVirt, MetalLB, cert-manager, and cluster operations.

Rules:
- All lifecycle actions MUST go through the hypercluster CLI (preflight, deploy, test, destroy, health, lab, vms, workloads). Never suggest raw kubectl/helm for deploy/destroy.
- k3s platform stack order: Cilium → cert-manager → MetalLB → KubeVirt/CDI → metrics-server.
- Re-deploy skips healthy k3s reinstall unless FORCE_K3S_REINSTALL=1.
- Be concise, actionable, and prioritize safety (confirm before destroy).
- When suggesting commands, use: hypercluster -c cluster.conf <command>.
- Format with markdown bullets and code blocks when helpful.`

export const AI_LOG_ANALYSIS_PROMPT = `Analyze these hypercluster deploy/preflight logs. Summarize:
1. What succeeded
2. Errors and root cause
3. Exact next steps (hypercluster commands only)
Keep under 250 words.`

export const AI_HEALTH_PROMPT = `Review the cluster health report. Explain status in plain language and list prioritized fixes. Mention failed platform tests and unhealthy pods if any.`

export const AI_SPEC_PROMPT = `Review this cluster spec. Suggest improvements for production HA, security (cert-manager), virtualization (KubeVirt), storage, and MetalLB. Flag single-node risks.`

export const QUICK_PROMPTS = [
  { id: 'health', label: 'Explain health', prompt: 'Explain the current cluster health and what I should do next.', icon: '◆' },
  { id: 'fix', label: 'Suggest fixes', prompt: 'What are the top 3 fixes for any issues in this cluster?', icon: '⚡' },
  { id: 'deploy-plan', label: 'Deploy plan', prompt: 'Give me a step-by-step deploy or redeploy plan for this cluster.', icon: '▶' },
  { id: 'security', label: 'Security review', prompt: 'Review security posture: TLS, cert-manager, network policy, SSH keys.', icon: '🔒' },
  { id: 'kubevirt', label: 'VM strategy', prompt: 'Recommend KubeVirt VM templates and storage for this lab.', icon: '◇' },
  { id: 'logs', label: 'Analyze logs', prompt: 'Analyze the recent job logs and tell me what failed and how to fix it.', icon: '📋' },
  { id: 'cost', label: 'Right-size', prompt: 'Is this cluster over-provisioned? Suggest a lean single-node lab config.', icon: '◎' },
  { id: 'upgrade', label: 'Upgrade path', prompt: 'What is the safest upgrade path for this cluster version?', icon: '↑' },
] as const
