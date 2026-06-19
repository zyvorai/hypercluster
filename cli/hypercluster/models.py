from __future__ import annotations

from pathlib import Path
from typing import Literal, Optional
from pydantic import BaseModel, field_validator


class ClusterConfig(BaseModel):
    CLUSTER_NAME: str
    K8S_DISTRO: Literal["kubespray", "k3s", "rke2", "microk8s", "talos", "kubeadm"] = "kubespray"
    SSH_USER: str = "root"
    SSH_KEY: str = "~/.ssh/id_rsa"
    SSH_PORT: int = 22
    SSH_EXTRA_ARGS: str = ""
    SSH_PROXY_JUMP: str = ""
    CONTROL_PLANE_IPS: str = ""
    WORKER_IPS: str = ""
    NODE_SSH_OVERRIDES_JSON: str = ""

    # Kubespray
    KUBESPRAY_VERSION: str = ""
    KUBESPRAY_DIR: str = ".kubespray"
    KUBE_VERSION: str = ""
    CONTAINER_MANAGER: str = "containerd"
    CNI_PLUGIN: str = "cilium"
    KUBE_PODS_SUBNET: str = "10.233.64.0/18"
    KUBE_SERVICE_ADDRESSES: str = "10.233.0.0/18"
    METRICS_SERVER_ENABLED: bool = True

    # k3s
    K3S_VERSION: str = ""
    K3S_CHANNEL: str = ""
    K3S_EXEC_ARGS: str = ""
    K3S_AGENT_EXEC_ARGS: str = ""
    K3S_DATA_DIR: str = ""
    K3S_API_LOCAL_PORT: str = ""
    FORCE_K3S_REINSTALL: bool = False

    # kubeconfig output
    KUBECONFIG_OUTPUT: str = "~/.kube/config"

    # Platform stack
    PLATFORM_STACK_ENABLED: bool = True
    PLATFORM_HELM_REPO_UPDATE: bool = True
    CERT_MANAGER_ENABLED: bool = True
    METALLB_ENABLED: bool = True
    METALLB_IP_POOL: str = ""
    KUBEVIRT_ENABLED: bool = False
    KUBEVIRT_REQUIRED: bool = False
    KUBEVIRT_VERSION: str = "v1.3.1"
    CDI_ENABLED: bool = True
    CDI_VERSION: str = "v1.59.0"
    CNAO_ENABLED: bool = True
    CNAO_HELM_REPO: str = ""
    SSP_ENABLED: bool = True
    SSP_HELM_REPO: str = ""
    CILIUM_K8S_SERVICE_HOST: str = "127.0.0.1"
    CILIUM_KUBE_PROXY_REPLACEMENT: bool = True
    CILIUM_HUBBLE_ENABLED: bool = True
    CILIUM_BGP_ENABLED: bool = False
    CILIUM_GATEWAY_API_ENABLED: bool = False
    CILIUM_WIREGUARD_ENABLED: bool = False
    LONGHORN_ENABLED: bool = False
    SNAPSHOT_CONTROLLER_ENABLED: bool = False
    DESCHEDULER_ENABLED: bool = False
    NFD_ENABLED: bool = False
    GPU_OPERATOR_ENABLED: bool = False

    # Helm chart versions (all optional, empty = latest)
    CERT_MANAGER_VERSION: str = ""
    CILIUM_CHART_VERSION: str = ""
    METALLB_CHART_VERSION: str = ""
    LONGHORN_CHART_VERSION: str = ""
    DESCHEDULER_CHART_VERSION: str = ""
    NFD_CHART_VERSION: str = ""
    GPU_OPERATOR_CHART_VERSION: str = ""

    # Lab
    LAB_SECONDARY_DISK: str = ""
    LAB_KUBEVIRT_VOLUME_MOUNT: str = ""
    LAB_MEMORY_TUNE_ENABLED: bool = False
    LAB_AUTO_SETUP: bool = False

    model_config = {"extra": "ignore"}

    @field_validator("K8S_DISTRO", mode="before")
    @classmethod
    def normalize_distro(cls, v: str) -> str:
        return v.strip().lower()

    def control_plane_ips(self) -> list[str]:
        return [ip.strip() for ip in self.CONTROL_PLANE_IPS.split() if ip.strip()]

    def worker_ips(self) -> list[str]:
        return [ip.strip() for ip in self.WORKER_IPS.split() if ip.strip()]

    def all_ips(self) -> list[str]:
        return self.control_plane_ips() + self.worker_ips()

    def first_cp_ip(self) -> str:
        ips = self.control_plane_ips()
        if not ips:
            raise ValueError(f"No control plane IPs in cluster config for {self.CLUSTER_NAME}")
        return ips[0]

    def resolved_ssh_key(self) -> str:
        return str(Path(self.SSH_KEY).expanduser())

    def resolved_kubeconfig(self) -> str:
        return str(Path(self.KUBECONFIG_OUTPUT).expanduser())

    def distro(self) -> str:
        d = self.K8S_DISTRO
        if d == "kubeadm":
            return "kubespray"
        return d
