from __future__ import annotations

from hypercluster import log
from hypercluster.models import ClusterConfig


def print_hints(cfg: ClusterConfig) -> None:
    kc = cfg.resolved_kubeconfig()
    print(f"\n\U0001f37e  Cluster '{cfg.CLUSTER_NAME}' is ready!\n", flush=True)
    print(f"    export KUBECONFIG={kc}")
    print(f"    kubectl get nodes")
    if cfg.KUBEVIRT_ENABLED:
        print(f"    kubectl get vms -A")
    print()
