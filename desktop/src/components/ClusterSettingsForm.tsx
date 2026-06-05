import { IpTags } from './IpTags'
import type { WizardForm } from '../lib/types'

export function ClusterSettingsForm({
  form,
  onChange,
  mode,
}: {
  form: WizardForm
  onChange: (form: WizardForm) => void
  mode: 'create' | 'edit'
}) {
  return (
    <div className="space-y-6">
      <section>
        <h3 className="mb-3 font-medium">Cluster identity</h3>
        <div className="space-y-3">
          <input
            className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2"
            value={form.clusterName}
            onChange={(e) => onChange({ ...form, clusterName: e.target.value })}
            placeholder="Cluster name"
            disabled={mode === 'edit'}
          />
          {mode === 'edit' && (
            <p className="text-xs text-glass-muted">
              Cluster name is fixed for registry entries. Create a new cluster to rename.
            </p>
          )}
          <select
            className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2"
            value={form.k8sDistro}
            onChange={(e) =>
              onChange({ ...form, k8sDistro: e.target.value as 'k3s' | 'kubespray' })
            }
          >
            <option value="k3s">k3s (remote platform stack)</option>
            <option value="kubespray">Kubespray (upstream HA)</option>
          </select>
          <input
            className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2"
            value={form.kubeVersion}
            onChange={(e) => onChange({ ...form, kubeVersion: e.target.value })}
            placeholder={form.k8sDistro === 'k3s' ? 'K3S_VERSION (e.g. v1.35.5+k3s1)' : 'KUBE_VERSION'}
          />
        </div>
      </section>

      <section>
        <h3 className="mb-3 font-medium">Nodes & SSH</h3>
        <div className="space-y-4">
          <IpTags
            label="Control plane IPs"
            hint="At least one IP required. These are the servers hypercluster SSHs into for deploy."
            ips={form.controlPlaneIps}
            onChange={(ips) => onChange({ ...form, controlPlaneIps: ips })}
          />
          <IpTags
            label="Worker IPs"
            hint="Optional. Add worker nodes to join after the control plane is up."
            ips={form.workerIps}
            onChange={(ips) => onChange({ ...form, workerIps: ips })}
          />
          <div className="grid gap-3 sm:grid-cols-2">
            <input
              className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2"
              value={form.sshUser}
              onChange={(e) => onChange({ ...form, sshUser: e.target.value })}
              placeholder="SSH user"
            />
            <input
              className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2"
              type="number"
              value={form.sshPort}
              onChange={(e) =>
                onChange({ ...form, sshPort: Number.parseInt(e.target.value, 10) || 22 })
              }
              placeholder="SSH port"
            />
          </div>
          <input
            className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2"
            value={form.sshKey}
            onChange={(e) => onChange({ ...form, sshKey: e.target.value })}
            placeholder="SSH private key path (e.g. $HOME/.ssh/id_ed25519)"
          />
          <button
            type="button"
            className="btn-ghost text-sm"
            onClick={async () => {
              const { pickSshKey } = await import('../lib/api')
              const path = await pickSshKey()
              if (path) onChange({ ...form, sshKey: path })
            }}
          >
            Browse SSH key…
          </button>
        </div>
      </section>

      <section>
        <h3 className="mb-3 font-medium">Network</h3>
        <div className="space-y-3">
          <input
            className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2"
            value={form.kubePodsSubnet}
            onChange={(e) => onChange({ ...form, kubePodsSubnet: e.target.value })}
            placeholder="Pod CIDR (KUBE_PODS_SUBNET)"
          />
          <input
            className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2"
            value={form.kubeServiceAddresses}
            onChange={(e) => onChange({ ...form, kubeServiceAddresses: e.target.value })}
            placeholder="Service CIDR (KUBE_SERVICE_ADDRESSES)"
          />
          <input
            className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2"
            value={form.cniPlugin}
            onChange={(e) => onChange({ ...form, cniPlugin: e.target.value })}
            placeholder="CNI plugin (e.g. cilium)"
          />
        </div>
      </section>

      <section>
        <h3 className="mb-3 font-medium">Platform stack</h3>
        <div className="space-y-3">
          <label className="flex items-center gap-2">
            <input
              type="checkbox"
              checked={form.metallbEnabled}
              onChange={(e) => onChange({ ...form, metallbEnabled: e.target.checked })}
            />
            MetalLB
          </label>
          {form.metallbEnabled && (
            <input
              className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2"
              value={form.metallbIpPool}
              onChange={(e) => onChange({ ...form, metallbIpPool: e.target.value })}
              placeholder="MetalLB IP pool (e.g. 192.168.1.240-192.168.1.250)"
            />
          )}
          <label className="flex items-center gap-2">
            <input
              type="checkbox"
              checked={form.certManagerEnabled}
              onChange={(e) => onChange({ ...form, certManagerEnabled: e.target.checked })}
            />
            cert-manager
          </label>
          <label className="flex items-center gap-2">
            <input
              type="checkbox"
              checked={form.metricsServerEnabled}
              onChange={(e) => onChange({ ...form, metricsServerEnabled: e.target.checked })}
            />
            metrics-server
          </label>
          <label className="flex items-center gap-2">
            <input
              type="checkbox"
              checked={form.kubevirtEnabled}
              onChange={(e) => onChange({ ...form, kubevirtEnabled: e.target.checked })}
            />
            KubeVirt + CDI
          </label>
          {form.kubevirtEnabled && (
            <>
              <label className="flex items-center gap-2">
                <input
                  type="checkbox"
                  checked={form.cnaoEnabled}
                  onChange={(e) => onChange({ ...form, cnaoEnabled: e.target.checked })}
                />
                CNAO (Multus)
              </label>
              <label className="flex items-center gap-2">
                <input
                  type="checkbox"
                  checked={form.sspEnabled}
                  onChange={(e) => onChange({ ...form, sspEnabled: e.target.checked })}
                />
                SSP templates
              </label>
              <div className="grid gap-3 sm:grid-cols-2">
                <input
                  className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2"
                  value={form.kubevirtVersion}
                  onChange={(e) => onChange({ ...form, kubevirtVersion: e.target.value })}
                  placeholder="KubeVirt version"
                />
                <input
                  className="w-full rounded-xl border border-glass-border bg-black/20 px-3 py-2"
                  value={form.cdiVersion}
                  onChange={(e) => onChange({ ...form, cdiVersion: e.target.value })}
                  placeholder="CDI version"
                />
              </div>
            </>
          )}
          <label className="flex items-center gap-2">
            <input
              type="checkbox"
              checked={form.longhornEnabled}
              onChange={(e) => onChange({ ...form, longhornEnabled: e.target.checked })}
            />
            Longhorn storage
          </label>
        </div>
      </section>
    </div>
  )
}
