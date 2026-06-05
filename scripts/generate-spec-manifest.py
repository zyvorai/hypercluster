#!/usr/bin/env python3
"""Generate spec-manifest.json for SettingsSearch — wired ClusterSpec keys only."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "desktop/src/lib/spec-manifest.json"

SPEC_FIELDS = [
    ("clusterName", "Cluster name", "Identity", "CLUSTER_NAME", "string"),
    ("environment", "Environment", "Identity", "ENVIRONMENT", "string"),
    ("description", "Description", "Identity", "DESCRIPTION", "string"),
    ("k8sDistro", "Kubernetes distro", "Distro", "K8S_DISTRO", "string"),
    ("deployModel", "Deploy model", "Distro", "DEPLOY_MODEL", "string"),
    ("kubesprayVersion", "Kubespray version", "Distro", "KUBESPRAY_VERSION", "string"),
    ("kubeVersion", "Kubernetes version", "Distro", "KUBE_VERSION", "string"),
    ("sshUser", "SSH user", "SSH", "SSH_USER", "string"),
    ("sshKey", "SSH private key", "SSH", "SSH_KEY", "string"),
    ("sshPort", "SSH port", "SSH", "SSH_PORT", "number"),
    ("sshProxyJump", "SSH proxy jump", "SSH", "SSH_PROXY_JUMP", "string"),
    ("kubePodsSubnet", "Pod CIDR", "Network", "KUBE_PODS_SUBNET", "string"),
    ("kubeServiceAddresses", "Service CIDR", "Network", "KUBE_SERVICE_ADDRESSES", "string"),
    ("cniPlugin", "CNI plugin", "Network", "CNI_PLUGIN", "string"),
    ("containerManager", "Container runtime", "Distro", "CONTAINER_MANAGER", "string"),
    ("ciliumHubble", "Cilium Hubble", "Network", "CILIUM_HUBBLE_ENABLED", "boolean"),
    ("ciliumBgp", "Cilium BGP", "Network", "CILIUM_BGP_ENABLED", "boolean"),
    ("ciliumWireguard", "Cilium WireGuard", "Network", "CILIUM_WIREGUARD_ENABLED", "boolean"),
    ("ciliumGatewayApi", "Cilium Gateway API", "Network", "CILIUM_GATEWAY_API_ENABLED", "boolean"),
    ("platformStackEnabled", "Platform stack", "Platform", "PLATFORM_STACK_ENABLED", "boolean"),
    ("metallbEnabled", "MetalLB", "Platform", "METALLB_ENABLED", "boolean"),
    ("metallbIpPool", "MetalLB IP pool", "Platform", "METALLB_IP_POOL", "string"),
    ("certManagerEnabled", "cert-manager", "Platform", "CERT_MANAGER_ENABLED", "boolean"),
    ("metricsServerEnabled", "metrics-server", "Platform", "METRICS_SERVER_ENABLED", "boolean"),
    ("kubevirtEnabled", "KubeVirt", "Virtualization", "KUBEVIRT_ENABLED", "boolean"),
    ("cnaoEnabled", "CNAO", "Virtualization", "CNAO_ENABLED", "boolean"),
    ("sspEnabled", "SSP", "Virtualization", "SSP_ENABLED", "boolean"),
    ("longhornEnabled", "Longhorn", "Storage", "LONGHORN_ENABLED", "boolean"),
    ("gpuOperatorEnabled", "GPU Operator", "GPU", "GPU_OPERATOR_ENABLED", "boolean"),
    ("nfdEnabled", "Node Feature Discovery", "GPU", "NFD_ENABLED", "boolean"),
    ("ingressNginxEnabled", "ingress-nginx", "Platform", "INGRESS_NGINX_ENABLED", "boolean"),
    ("kubevirtVersion", "KubeVirt version", "Virtualization", "KUBEVIRT_VERSION", "string"),
    ("cdiVersion", "CDI version", "Virtualization", "CDI_VERSION", "string"),
    ("haControlPlane", "HA control plane preset", "Nodes", "HA_CONTROL_PLANE", "string"),
]

CATALOG = [
    ("Kyverno", "Security", "KYVERNO_ENABLED", "Policy engine — not wired to ClusterSpec yet"),
    ("Falco", "Security", "FALCO_ENABLED", "Runtime security — coming soon"),
    ("Velero", "Backup", "VELERO_ENABLED", "Cluster backup — coming soon"),
    ("Prometheus", "Observability", "PROMETHEUS_ENABLED", "Metrics stack — coming soon"),
    ("KServe", "AI", "KSERVE_ENABLED", "Model serving — coming soon"),
    ("vLLM", "AI", "VLLM_ENABLED", "LLM serving — coming soon"),
]


def main():
    entries = []
    for key, label, group, conf, typ in SPEC_FIELDS:
        entries.append({
            "key": key,
            "label": label,
            "description": f"ClusterSpec.{key} → {conf}",
            "group": group,
            "confKey": conf,
            "type": typ,
            "specPath": key,
            "wired": True,
        })

    for label, group, conf, desc in CATALOG:
        entries.append({
            "key": conf.lower(),
            "label": label,
            "description": desc,
            "group": group,
            "confKey": conf,
            "type": "boolean",
            "wired": False,
        })

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(entries, indent=2) + "\n")
    wired = sum(1 for e in entries if e.get("wired"))
    print(f"Wrote {len(entries)} entries ({wired} wired) to {OUT}")


if __name__ == "__main__":
    main()
