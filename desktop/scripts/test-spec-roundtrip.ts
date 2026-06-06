#!/usr/bin/env node
/** Roundtrip test: specToClusterConf ↔ parseClusterSpec */
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

const root = join(dirname(fileURLToPath(import.meta.url)), '../..')
// Dynamic import compiled TS — run via: cd desktop && npx tsx scripts/test-spec-roundtrip.ts
const { specToClusterConf, parseClusterSpec, defaultClusterSpec } = await import('../src/lib/clusterSpec.ts')
const { applyStudioTemplate } = await import('../src/lib/templates.ts')

let failed = 0
function assert(cond: boolean, msg: string) {
  if (!cond) {
    console.error('FAIL:', msg)
    failed++
  } else {
    console.log('PASS:', msg)
  }
}

const spec = applyStudioTemplate('kubevirt-lab')
spec.clusterName = 'roundtrip-test'
spec.controlPlaneIps = ['10.0.0.1']
spec.workerIps = ['10.0.0.2']
const conf = specToClusterConf(spec)
const back = parseClusterSpec(conf, 'roundtrip-test')
assert(back.clusterName === 'roundtrip-test', 'cluster name roundtrip')
assert(back.controlPlaneIps.join(' ') === '10.0.0.1', 'control plane roundtrip')
assert(back.workerIps.join(' ') === '10.0.0.2', 'worker roundtrip')
assert(back.kubevirtEnabled === true, 'kubevirt roundtrip')
assert(back.labSecondaryDisk === '/dev/sdb', 'lab disk roundtrip')
assert(back.labAutoSetup === true, 'lab auto setup roundtrip')

const labConf = specToClusterConf(spec)
assert(labConf.includes('LAB_SECONDARY_DISK="/dev/sdb"'), 'lab vars in conf')

const example = readFileSync(join(root, 'config/cluster.conf.example'), 'utf8')
const parsed = parseClusterSpec(example)
assert(parsed.clusterName === 'mycluster', 'parse example CLUSTER_NAME')
assert(example.includes('LAB_SECONDARY_DISK='), 'example documents LAB_SECONDARY_DISK')

if (failed) process.exit(1)
console.log('spec roundtrip tests passed')
