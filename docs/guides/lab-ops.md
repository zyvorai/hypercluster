# Lab operations (single-node k3s)

Use **`hypercluster lab`** after deploying a single-node k3s platform stack when you run many Zyvor apps (Forge, KubeVirt, Zeus OS, …) on one host and need:

- **Secondary disk** for KubeVirt VM PVCs (keep k3s/etcd on the root volume)
- **Memory relief** by scaling down HA replica counts

## cluster.conf

```bash
LAB_SECONDARY_DISK="/dev/sdb"
LAB_KUBEVIRT_VOLUME_MOUNT="/data/kubevirt-volumes"
LAB_KUBEVIRT_STORAGE_CLASS="kubevirt-sdb"
LAB_STORAGE_FORMAT="1"              # only when disk is empty (mkfs — destructive)

LAB_MEMORY_TUNE_ENABLED="true"
LAB_AUTO_SETUP="true"               # run lab setup at end of deploy
```

| Variable | Purpose |
|----------|---------|
| `LAB_SECONDARY_DISK` | Block device to mount (e.g. `/dev/sdb`). Empty = skip storage. |
| `LAB_KUBEVIRT_VOLUME_MOUNT` | Host mount point (default `/data/kubevirt-volumes`). |
| `LAB_KUBEVIRT_STORAGE_CLASS` | Kubernetes StorageClass name (default `kubevirt-sdb`). |
| `LAB_STORAGE_FORMAT` | `1` allows `mkfs.xfs` on an unformatted disk. |
| `LAB_MEMORY_TUNE_ENABLED` | Scale Forge UI, IronWolf, snapshot-controller, etc. to 1 replica. |
| `LAB_AUTO_SETUP` | Run `lab setup` automatically after `hypercluster deploy`. |

## Commands

```bash
# All-in-one from cluster.conf
./hypercluster -c cluster.conf lab setup

# Secondary disk: mount + local-path paths + StorageClass
./hypercluster -c cluster.conf lab storage
./hypercluster -c cluster.conf lab storage --status

# Memory tune (single-node)
./hypercluster -c cluster.conf lab tune
./hypercluster -c cluster.conf lab tune --restore
```

Make targets:

```bash
make lab-setup CONFIG=cluster.conf
make lab-storage CONFIG=cluster.conf
make lab-tune CONFIG=cluster.conf
```

Legacy script wrappers (call hypercluster):

- `scripts/lab-storage-setup.sh`
- `scripts/lab-memory-tune.sh`

## KubeVirt VM disks

After `lab storage`, create DataVolumes with the lab StorageClass:

```yaml
spec:
  storage:
    storageClassName: kubevirt-sdb
    resources:
      requests:
        storage: 20Gi
```

Reference manifest: `config/manifests/lab/kubevirt-sdb-storageclass.yaml`

## Notes

- **KubeVirt** may restore `virt-controller` to 2 replicas on reconcile (HA default).
- **Formatting** (`LAB_STORAGE_FORMAT=1`) erases the target disk — double-check `LAB_SECONDARY_DISK`.
- **Sibling app deploys** (VMRogue, HyperSDK, …) remain in their own repos; hypercluster lab only tunes the k3s platform host and cluster.
