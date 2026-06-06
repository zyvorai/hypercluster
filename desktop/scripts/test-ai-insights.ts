import { generateInsights, insightCounts } from '../src/lib/ai/insights'
import type { HealthJson } from '../src/lib/types'

const health: HealthJson = {
  cluster: 'test',
  connected: true,
  state: 'degraded',
  kubeconfig: '/tmp/kc',
  issues: ['1 pod failed'],
  status: { ready: 1, total: 1, nodes: [] },
  workloads: {
    pods: [
      {
        namespace: 'default',
        name: 'bad-pod',
        phase: 'Failed',
        node: '',
        ready: 0,
        containers: 1,
      },
    ],
    services: [],
  },
  vms: { vms: [], templates: [] },
  summary: {
    nodes_ready: 1,
    nodes_total: 1,
    pods_running: 5,
    pods_total: 6,
    pods_pending: 0,
    pods_failed: 1,
    services: 2,
    vms_running: 0,
    vms_total: 0,
  },
  tests: null,
}

const insights = generateInsights({
  cluster: {
    id: '1',
    name: 'lab',
    config_path: '/tmp/c',
    distro: 'k3s',
    created_at: '',
  },
  health,
})

const counts = insightCounts(insights)
if (counts.critical + counts.warn < 1) {
  console.error('expected warn/critical insights', insights)
  process.exit(1)
}
const failedPod = insights.find((i) => i.title.includes('failed pod'))
if (!failedPod?.detail.includes('bad-pod')) {
  console.error('expected failed pod name in detail', failedPod)
  process.exit(1)
}
console.log('PASS: AI insights generation')
console.log(`  ${insights.length} insights (${counts.critical} critical, ${counts.warn} warn)`)
