from __future__ import annotations

import os
import subprocess
import tempfile
from pathlib import Path

from hypercluster import log, proc
from hypercluster.models import ClusterConfig
from hypercluster.paths import config_dir


def _kc_env(cfg: ClusterConfig) -> dict:
    kc = cfg.resolved_kubeconfig()
    if not Path(kc).is_file():
        log.die(f"kubeconfig not found: {kc}")
    return dict(os.environ, KUBECONFIG=kc)


def _helm(cfg: ClusterConfig, *args: str) -> int:
    if proc.DRY_RUN:
        log.warn(f"DRY RUN — helm {' '.join(args)}")
        return 0
    env = _kc_env(cfg)
    return proc.run_stream(["helm"] + list(args), env=env)


def _kubectl(cfg: ClusterConfig, *args: str) -> int:
    if proc.DRY_RUN:
        log.warn(f"DRY RUN — kubectl {' '.join(args)}")
        return 0
    env = _kc_env(cfg)
    return proc.run_stream(["kubectl"] + list(args), env=env)


def _kubectl_capture(cfg: ClusterConfig, *args: str) -> str:
    env = _kc_env(cfg)
    return proc.capture(["kubectl"] + list(args), env=env)


def _helm_capture(cfg: ClusterConfig, *args: str) -> str:
    env = _kc_env(cfg)
    return proc.capture(["helm"] + list(args), env=env)


def _version_arg(version: str) -> list[str]:
    return ["--version", version] if version else []


def _helm_unstick(release: str, namespace: str, cfg: ClusterConfig) -> None:
    import json
    raw = _helm_capture(cfg, "status", release, "-n", namespace, "-o", "json")
    try:
        status = json.loads(raw).get("info", {}).get("status", "")
    except (json.JSONDecodeError, AttributeError):
        status = ""
    if status in ("pending-install", "pending-upgrade", "pending-rollback", "uninstalling", "failed"):
        log.warn(f"Clearing stuck Helm release {release} ({status}) in {namespace} …")
        _helm(cfg, "uninstall", release, "-n", namespace, "--no-hooks")
        import time
        time.sleep(3)


def _helm_wait_or_ready(release: str, namespace: str, cfg: ClusterConfig, timeout: str = "10m", *extra: str) -> None:
    _helm_unstick(release, namespace, cfg)
    rc = _helm(cfg, "upgrade", "--install", release, *extra,
               "--namespace", namespace, "--create-namespace",
               "--wait", "--timeout", timeout)
    if rc == 0:
        return
    log.warn(f"{release} helm --wait failed — verifying workloads in {namespace} …")
    env = _kc_env(cfg)
    r1 = subprocess.run(
        ["kubectl", "wait", "--for=condition=Available", "deployment", "--all",
         "-n", namespace, "--timeout=600s"],
        env=env, capture_output=True,
    )
    r2 = subprocess.run(
        ["kubectl", "wait", "--for=condition=Ready", "pod", "--all",
         "-n", namespace, "--timeout=600s"],
        env=env, capture_output=True,
    )
    if r1.returncode == 0 or r2.returncode == 0:
        log.ok(f"{release} workloads ready (skipping stuck helm reconcile)")
        return
    _helm_unstick(release, namespace, cfg)
    _helm(cfg, "upgrade", "--install", release, *extra,
          "--namespace", namespace, "--create-namespace", "--timeout", "5m")


def ensure_helm_repos(cfg: ClusterConfig) -> None:
    log.info("Adding Helm repositories …")
    repos = [
        ("cilium", "https://helm.cilium.io"),
        ("metallb", "https://metallb.github.io/metallb"),
        ("kubevirt", "https://kubevirt.github.io/helm-charts"),
        ("jetstack", "https://charts.jetstack.io"),
        ("piraeus", "https://piraeus.io/helm-charts"),
        ("longhorn", "https://charts.longhorn.io"),
        ("descheduler", "https://kubernetes-sigs.github.io/descheduler/"),
        ("nfd", "https://kubernetes-sigs.github.io/node-feature-discovery/charts"),
        ("nvidia", "https://helm.ngc.nvidia.com/nvidia"),
    ]
    for name, url in repos:
        _helm(cfg, "repo", "add", name, url)
    if cfg.PLATFORM_HELM_REPO_UPDATE:
        _helm(cfg, "repo", "update")


def _gen_cilium_values(cfg: ClusterConfig) -> str:
    tpl = config_dir() / "k3s" / "cilium-values.yaml"
    if not tpl.is_file():
        log.die(f"Missing cilium values template: {tpl}")
    text = tpl.read_text()
    replacements = {
        "K8S_SERVICE_HOST": cfg.CILIUM_K8S_SERVICE_HOST or "127.0.0.1",
        "POD_CIDR": cfg.KUBE_PODS_SUBNET or "10.42.0.0/16",
        "KUBE_PROXY_REPLACEMENT": str(cfg.CILIUM_KUBE_PROXY_REPLACEMENT).lower(),
        "HUBBLE_ENABLED": str(cfg.CILIUM_HUBBLE_ENABLED).lower(),
        "GATEWAY_API_ENABLED": str(cfg.CILIUM_GATEWAY_API_ENABLED).lower(),
        "BGP_CONTROL_PLANE_ENABLED": str(cfg.CILIUM_BGP_ENABLED).lower(),
        "ENCRYPTION_ENABLED": str(cfg.CILIUM_WIREGUARD_ENABLED).lower(),
    }
    for k, v in replacements.items():
        text = text.replace(k, v)
    return text


def install_cert_manager(cfg: ClusterConfig) -> None:
    if not cfg.CERT_MANAGER_ENABLED:
        return
    log.section("cert-manager")
    ver_args = _version_arg(cfg.CERT_MANAGER_VERSION)
    _helm_wait_or_ready(
        "cert-manager", "cert-manager", cfg, "10m",
        "jetstack/cert-manager", *ver_args, "--set", "crds.enabled=true",
    )
    log.info("Recycling cert-manager pods (fresh CNI routes after Cilium) …")
    _kubectl(cfg, "delete", "pods", "-n", "cert-manager", "--all", "--force", "--grace-period=0")
    _kubectl(cfg, "wait", "--for=condition=Available", "deployment", "--all",
             "-n", "cert-manager", "--timeout=600s")
    log.ok("cert-manager ready")


def install_cilium(cfg: ClusterConfig) -> None:
    log.section("Cilium CNI")
    values_text = _gen_cilium_values(cfg)
    with tempfile.NamedTemporaryFile(mode="w", suffix="-cilium-values.yaml", delete=False) as f:
        f.write(values_text)
        values_path = f.name
    try:
        ver_args = _version_arg(cfg.CILIUM_CHART_VERSION)
        _helm_wait_or_ready(
            "cilium", "kube-system", cfg, "10m",
            "cilium/cilium", *ver_args, "-f", values_path,
        )
    finally:
        Path(values_path).unlink(missing_ok=True)
    log.ok("Cilium ready")


def install_metallb(cfg: ClusterConfig) -> None:
    if not cfg.METALLB_ENABLED:
        return
    log.section("MetalLB")
    ver_args = _version_arg(cfg.METALLB_CHART_VERSION)
    _helm_wait_or_ready("metallb", "metallb-system", cfg, "5m", "metallb/metallb", *ver_args)
    if cfg.METALLB_IP_POOL:
        import time
        time.sleep(5)
        pool_yaml = (
            f"apiVersion: metallb.io/v1beta1\nkind: IPAddressPool\nmetadata:\n"
            f"  name: default-pool\n  namespace: metallb-system\nspec:\n"
            f"  addresses:\n  - {cfg.METALLB_IP_POOL}\n---\n"
            f"apiVersion: metallb.io/v1beta1\nkind: L2Advertisement\nmetadata:\n"
            f"  name: default\n  namespace: metallb-system\n"
        )
        with tempfile.NamedTemporaryFile(mode="w", suffix="-metallb-pool.yaml", delete=False) as f:
            f.write(pool_yaml)
            pool_path = f.name
        try:
            _kubectl(cfg, "apply", "-f", pool_path)
        finally:
            Path(pool_path).unlink(missing_ok=True)
    log.ok("MetalLB ready")


def install_kubevirt(cfg: ClusterConfig) -> None:
    kv_ver = cfg.KUBEVIRT_VERSION or "v1.3.1"
    cdi_ver = cfg.CDI_VERSION or "v1.59.0"
    kc = cfg.resolved_kubeconfig()
    if not Path(kc).is_file():
        if cfg.KUBEVIRT_REQUIRED:
            log.die(f"kubeconfig not found at {kc} — cannot install KubeVirt. Run 'fetch-kubeconfig' first.")
        log.warn(f"kubeconfig not found at {kc} — skipping KubeVirt install.")
        return

    base = f"https://github.com/kubevirt/kubevirt/releases/download/{kv_ver}"
    log.info(f"Deploying KubeVirt operator {kv_ver} …")
    _kubectl(cfg, "apply", "-f", f"{base}/kubevirt-operator.yaml")
    _kubectl(cfg, "apply", "-f", f"{base}/kubevirt-cr.yaml")
    log.info("Waiting for KubeVirt to be ready (up to 10 min) …")
    _kubectl(cfg, "-n", "kubevirt", "wait", "kubevirt", "kubevirt",
             "--for=condition=Available", "--timeout=600s")

    log.info(f"Deploying CDI {cdi_ver} …")
    cdi_base = f"https://github.com/kubevirt/containerized-data-importer/releases/download/{cdi_ver}"
    _kubectl(cfg, "apply", "-f", f"{cdi_base}/cdi-operator.yaml")
    _kubectl(cfg, "apply", "-f", f"{cdi_base}/cdi-cr.yaml")
    _kubectl(cfg, "-n", "cdi", "wait", "cdi", "cdi",
             "--for=condition=Available", "--timeout=300s")
    log.ok(f"KubeVirt {kv_ver} + CDI {cdi_ver} installed ✅")


def install_stack(cfg: ClusterConfig) -> None:
    log.section("Platform stack installation")
    ensure_helm_repos(cfg)
    install_cert_manager(cfg)
    install_cilium(cfg)
    install_metallb(cfg)
    if cfg.KUBEVIRT_ENABLED:
        install_kubevirt(cfg)
    log.ok("Platform stack installed ✅")
