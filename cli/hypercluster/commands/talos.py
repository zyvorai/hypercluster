from __future__ import annotations

from hypercluster import log
from hypercluster.models import ClusterConfig


def deploy(cfg: ClusterConfig) -> None:
    log.warn("Talos bootstrap is a stub — full implementation pending.")
    log.info(f"Cluster: {cfg.CLUSTER_NAME}")
    log.info(f"Control plane: {cfg.CONTROL_PLANE_IPS}")
    log.die("Talos deploy not yet implemented. Use K8S_DISTRO=k3s or kubespray instead.")
