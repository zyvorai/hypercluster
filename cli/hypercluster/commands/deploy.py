from __future__ import annotations

from pathlib import Path

from hypercluster import log, proc
from hypercluster.models import ClusterConfig
from hypercluster.paths import anchor_dir
from hypercluster.commands import progress
from hypercluster.commands import preflight as pfmod
from hypercluster.commands import k3s, kubespray, inventory, kubeconfig
from hypercluster.commands import platform_stack, platform_tools, platform_test
from hypercluster.commands import postdeploy


def _kubespray_dir(cfg: ClusterConfig) -> Path:
    ks_raw = cfg.KUBESPRAY_DIR or ".kubespray"
    if Path(ks_raw).is_absolute():
        return Path(ks_raw)
    return anchor_dir() / ks_raw


def cmd_init(cfg: ClusterConfig, force: bool = False, profile: str = "") -> None:
    distro = cfg.distro()
    if distro in ("k3s", "rke2", "microk8s", "talos"):
        log.section(f"Init: {distro} (no Kubespray inventory)")
        log.ok(f"{distro} mode — config validated, ready to deploy.")
        return

    log.section("Init: Kubespray source + inventory")
    ks_dir = _kubespray_dir(cfg)
    kubespray.ensure_source(ks_dir, cfg.KUBESPRAY_VERSION, force=force)
    inventory.init(ks_dir, cfg, force=force)


def cmd_preflight(cfg: ClusterConfig, json_mode: bool = False) -> bool:
    runner = pfmod.PreflightRunner(cfg, json_mode=json_mode)
    return runner.run()


def cmd_deploy(cfg: ClusterConfig, force: bool = False) -> None:
    distro = cfg.distro()
    log.section(f"Deploy cluster: {cfg.CLUSTER_NAME} ({distro})")

    if distro == "k3s":
        progress.stage(1, 7, "Preflight checks")
        cmd_preflight(cfg)
        progress.stage(2, 7, "Init — validate k3s config")
        cmd_init(cfg, force=force)
        progress.stage(3, 7, "k3s install (server + workers, no Flannel/Traefik)")
        k3s.deploy(cfg)
        progress.stage(4, 7, "Fetch kubeconfig (laptop + remote user)")
        kubeconfig.fetch_k3s(cfg)
        k3s.wait_api(cfg)
        k3s.install_remote_kubeconfig(cfg)
        progress.stage(5, 7, "Platform stack (Cilium, MetalLB, KubeVirt, CDI, …)")
        if cfg.PLATFORM_STACK_ENABLED:
            platform_stack.install_stack(cfg)
        progress.stage(6, 7, "Remote CLI tools + kubeconfig merge")
        platform_tools.install_remote(cfg)
        platform_tools.merge_laptop_kubeconfig(cfg)
        progress.stage(7, 7, "Done")
        log.ok("k3s virtualization platform deployed! \U0001f389")
        if cfg.LAB_AUTO_SETUP:
            from hypercluster.commands.lab import setup as lab_setup
            lab_setup(cfg)
        postdeploy.print_hints(cfg)
        return

    if distro == "rke2":
        from hypercluster.commands.rke2 import deploy as rke2_deploy, fetch_kubeconfig as rke2_kc
        progress.stage(1, 5, "Preflight checks")
        cmd_preflight(cfg)
        progress.stage(2, 5, "RKE2 install (servers + agents)")
        rke2_deploy(cfg)
        progress.stage(3, 5, "Fetch kubeconfig")
        rke2_kc(cfg)
        progress.stage(4, 5, "Platform stack (optional)")
        if cfg.PLATFORM_STACK_ENABLED:
            platform_stack.install_stack(cfg)
        progress.stage(5, 5, "Done")
        log.ok("RKE2 cluster deployed! \U0001f389")
        postdeploy.print_hints(cfg)
        return

    if distro == "microk8s":
        from hypercluster.commands.microk8s import deploy as mk_deploy, fetch_kubeconfig as mk_kc
        progress.stage(1, 4, "Preflight checks")
        cmd_preflight(cfg)
        progress.stage(2, 4, "MicroK8s snap install + join")
        mk_deploy(cfg)
        progress.stage(3, 4, "Fetch kubeconfig")
        mk_kc(cfg)
        progress.stage(4, 4, "Done")
        log.ok("MicroK8s cluster deployed! \U0001f389")
        postdeploy.print_hints(cfg)
        return

    if distro == "talos":
        from hypercluster.commands.talos import deploy as talos_deploy
        talos_deploy(cfg)
        return

    # Kubespray
    progress.stage(1, 4, "Preflight checks")
    cmd_preflight(cfg)
    progress.stage(2, 4, "Init — Kubespray + inventory")
    cmd_init(cfg, force=force)
    ks_dir = _kubespray_dir(cfg)
    progress.stage(3, 4, "Kubespray cluster.yml (typically 15–30 min)")
    kubespray.run_playbook(ks_dir, "cluster.yml", cfg)
    log.ok("Cluster deployed! \U0001f389")
    progress.stage(4, 4, "Fetch kubeconfig + optional add-ons")
    kubeconfig.fetch(ks_dir, cfg)
    if cfg.KUBEVIRT_ENABLED:
        platform_stack.install_kubevirt(cfg)
    postdeploy.print_hints(cfg)


def cmd_scale(cfg: ClusterConfig) -> None:
    log.section(f"Scale cluster: {cfg.CLUSTER_NAME}")
    ks_dir = _kubespray_dir(cfg)
    inv_dir = ks_dir / "inventory" / cfg.CLUSTER_NAME
    if not inv_dir.is_dir():
        log.die("Inventory not found. Run 'init' first.")
    inventory.generate_hosts_yaml(inv_dir, cfg)
    inventory.generate_group_vars(inv_dir, cfg)
    kubespray.run_playbook(ks_dir, "scale.yml", cfg)
    log.ok("Scale complete ✅")


def cmd_upgrade(cfg: ClusterConfig) -> None:
    log.section(f"Upgrade cluster → {cfg.KUBE_VERSION}")
    ks_dir = _kubespray_dir(cfg)
    inv_dir = ks_dir / "inventory" / cfg.CLUSTER_NAME
    if not inv_dir.is_dir():
        log.die("Inventory not found. Run 'init' first.")
    kubespray.run_playbook(ks_dir, "upgrade_cluster.yml", cfg)
    log.ok("Upgrade complete ✅")


def cmd_remove_node(cfg: ClusterConfig, node: str, force: bool = False) -> None:
    if not node:
        log.die("Usage: hypercluster remove-node <node-name>")
    log.section(f"Remove node: {node}")
    extra = ["-e", f"node={node}", "-e", "reset_nodes=true"]
    if force:
        log.warn("Forcing ungraceful removal (--force).")
        extra += ["-e", "allow_ungraceful_removal=true"]
    ks_dir = _kubespray_dir(cfg)
    kubespray.run_playbook(ks_dir, "remove_node.yml", cfg, extra_args=extra)
    log.ok(f"Node {node} removed ✅")


def cmd_destroy(cfg: ClusterConfig, force: bool = False) -> None:
    log.section(f"⚠️  DESTROY cluster: {cfg.CLUSTER_NAME}")
    if not force:
        confirm = input(f"Type the cluster name to confirm destruction ({cfg.CLUSTER_NAME}): ")
        if confirm != cfg.CLUSTER_NAME:
            log.die("Aborted.")
    if cfg.distro() == "k3s":
        k3s.destroy(cfg, force=force)
        log.ok("k3s cluster destroyed.")
        return
    ks_dir = _kubespray_dir(cfg)
    kubespray.run_playbook(ks_dir, "reset.yml", cfg, extra_args=["-e", "reset_confirmation=yes"])
    log.ok("Cluster destroyed.")
