from __future__ import annotations

import sys
from pathlib import Path

import click

from hypercluster import log, proc
from hypercluster.paths import read_version


# ── helpers ────────────────────────────────────────────────────────────────────

def _load_cfg(ctx: click.Context) -> "ClusterConfig":
    from hypercluster.config import load_config
    config_path = ctx.obj["config_path"]
    try:
        return load_config(config_path)
    except FileNotFoundError as e:
        log.die(str(e))
    except Exception as e:
        log.die(f"Failed to load config '{config_path}': {e}")


def _with_lock(cfg: "ClusterConfig"):
    from hypercluster import lock
    return lock.acquire(cfg.CLUSTER_NAME)


# ── CLI root ───────────────────────────────────────────────────────────────────

@click.group()
@click.option("-c", "--config", "config_path", default="./cluster.conf",
              help="Path to cluster config (default: ./cluster.conf)")
@click.option("-f", "--force", is_flag=True, help="Force overwrite of existing inventory")
@click.option("-n", "--dry-run", is_flag=True, help="Print what would be executed, skip actual changes")
@click.option("-v", "--verbose", is_flag=True, help="Verbose output")
@click.option("-V", "--version", is_flag=True, is_eager=True, expose_value=False,
              callback=lambda ctx, param, v: (print(read_version()), ctx.exit()) if v else None,
              help="Show version")
@click.pass_context
def cli(ctx: click.Context, config_path: str, force: bool, dry_run: bool, verbose: bool) -> None:
    ctx.ensure_object(dict)
    ctx.obj["config_path"] = config_path
    ctx.obj["force"] = force
    ctx.obj["dry_run"] = dry_run
    ctx.obj["verbose"] = verbose

    proc.DRY_RUN = dry_run
    log.VERBOSE = verbose


# ── wizard / discover (no cluster.conf required) ───────────────────────────────

@cli.command("wizard")
@click.pass_context
def wizard_cmd(ctx: click.Context) -> None:
    """Interactive cluster.conf generator."""
    from hypercluster.commands.wizard import write_config
    write_config(ctx.obj["config_path"])


@cli.command("discover")
@click.option("--source", default="libvirt",
              type=click.Choice(["libvirt", "ssh-scan", "csv"]),
              help="Discovery source")
@click.option("--hosts", default="", help="IP range or CSV for ssh-scan")
@click.option("--csv-file", default="", help="CSV file for csv source")
@click.option("--json", "as_json", is_flag=True, help="JSON output")
@click.pass_context
def discover_cmd(ctx: click.Context, source: str, hosts: str, csv_file: str, as_json: bool) -> None:
    """Discover VMs/hosts (libvirt, Proxmox, VMware, ssh-scan, csv)."""
    from hypercluster.commands.discover import run
    run(source=source, json_mode=as_json, hosts=hosts, csv_file=csv_file)


# ── commands requiring cluster.conf ───────────────────────────────────────────

@cli.command("init")
@click.option("--wizard", "run_wizard", is_flag=True, help="Run wizard first")
@click.option("--profile", default="", help="Copy config/profiles/<name>.conf.example")
@click.pass_context
def init_cmd(ctx: click.Context, run_wizard: bool, profile: str) -> None:
    """Clone Kubespray and generate inventory + group_vars."""
    if run_wizard:
        from hypercluster.commands.wizard import write_config
        write_config(ctx.obj["config_path"])
    cfg = _load_cfg(ctx)
    from hypercluster.commands.deploy import cmd_init
    cmd_init(cfg, force=ctx.obj["force"], profile=profile)


@cli.command("preflight")
@click.option("--json", "as_json", is_flag=True, help="JSON output")
@click.pass_context
def preflight_cmd(ctx: click.Context, as_json: bool) -> None:
    """Verify local tools and SSH connectivity to all nodes."""
    cfg = _load_cfg(ctx)
    from hypercluster.commands.deploy import cmd_preflight
    ok = cmd_preflight(cfg, json_mode=as_json)
    if not ok:
        sys.exit(1)


@cli.command("deploy")
@click.pass_context
def deploy_cmd(ctx: click.Context) -> None:
    """Full cluster deployment (preflight + init + cluster)."""
    cfg = _load_cfg(ctx)
    lock_dir = _with_lock(cfg)
    try:
        from hypercluster.commands.deploy import cmd_deploy
        cmd_deploy(cfg, force=ctx.obj["force"])
    finally:
        from hypercluster import lock
        lock.release(lock_dir)


@cli.command("scale")
@click.pass_context
def scale_cmd(ctx: click.Context) -> None:
    """Add worker nodes listed in cluster.conf."""
    cfg = _load_cfg(ctx)
    lock_dir = _with_lock(cfg)
    try:
        from hypercluster.commands.deploy import cmd_scale
        cmd_scale(cfg)
    finally:
        from hypercluster import lock
        lock.release(lock_dir)


@cli.command("upgrade")
@click.pass_context
def upgrade_cmd(ctx: click.Context) -> None:
    """Upgrade Kubernetes to the version in cluster.conf."""
    cfg = _load_cfg(ctx)
    lock_dir = _with_lock(cfg)
    try:
        from hypercluster.commands.deploy import cmd_upgrade
        cmd_upgrade(cfg)
    finally:
        from hypercluster import lock
        lock.release(lock_dir)


@cli.command("remove-node")
@click.argument("node")
@click.pass_context
def remove_node_cmd(ctx: click.Context, node: str) -> None:
    """Drain and remove a single node."""
    cfg = _load_cfg(ctx)
    lock_dir = _with_lock(cfg)
    try:
        from hypercluster.commands.deploy import cmd_remove_node
        cmd_remove_node(cfg, node, force=ctx.obj["force"])
    finally:
        from hypercluster import lock
        lock.release(lock_dir)


@cli.command("fetch-kubeconfig")
@click.pass_context
def fetch_kubeconfig_cmd(ctx: click.Context) -> None:
    """Copy admin.conf from the first control-plane node."""
    cfg = _load_cfg(ctx)
    from hypercluster.commands.kubeconfig import fetch
    from hypercluster.paths import anchor_dir
    ks_dir = anchor_dir() / (cfg.KUBESPRAY_DIR or ".kubespray")
    fetch(ks_dir, cfg)


@cli.command("merge-kubeconfig")
@click.pass_context
def merge_kubeconfig_cmd(ctx: click.Context) -> None:
    """Merge cluster kubeconfig into ~/.kube/config."""
    cfg = _load_cfg(ctx)
    from hypercluster.commands.kubeconfig import merge_into_default
    merge_into_default(cfg)


@cli.command("install-kubevirt")
@click.pass_context
def install_kubevirt_cmd(ctx: click.Context) -> None:
    """Install KubeVirt operator + CDI."""
    cfg = _load_cfg(ctx)
    from hypercluster.commands.platform_stack import install_kubevirt
    install_kubevirt(cfg)


@cli.command("test")
@click.option("--json", "as_json", is_flag=True, help="JSON output")
@click.option("--full", is_flag=True, help="Run full test suite")
@click.pass_context
def test_cmd(ctx: click.Context, as_json: bool, full: bool) -> None:
    """Run platform smoke tests (k3s path)."""
    cfg = _load_cfg(ctx)
    from hypercluster.commands.platform_test import run
    ok = run(cfg, json_mode=as_json, full=full)
    if not ok:
        sys.exit(1)


@cli.command("destroy")
@click.pass_context
def destroy_cmd(ctx: click.Context) -> None:
    """Tear down the cluster."""
    cfg = _load_cfg(ctx)
    lock_dir = _with_lock(cfg)
    try:
        from hypercluster.commands.deploy import cmd_destroy
        cmd_destroy(cfg, force=ctx.obj["force"])
    finally:
        from hypercluster import lock
        lock.release(lock_dir)


@cli.command("status")
@click.option("--json", "as_json", is_flag=True, help="JSON output")
@click.pass_context
def status_cmd(ctx: click.Context, as_json: bool) -> None:
    """Node status."""
    cfg = _load_cfg(ctx)
    from hypercluster.commands.status import cmd_status
    cmd_status(cfg, json_mode=as_json)


@cli.command("health")
@click.option("--json", "as_json", is_flag=True, help="JSON output")
@click.option("--with-test", is_flag=True, help="Include platform smoke tests (k3s)")
@click.pass_context
def health_cmd(ctx: click.Context, as_json: bool, with_test: bool) -> None:
    """Connect + report nodes, pods, services, VMs."""
    cfg = _load_cfg(ctx)
    from hypercluster.commands.health import run
    run(cfg, json_mode=as_json, with_test=with_test)


@cli.command("vms")
@click.option("--json", "as_json", is_flag=True, help="JSON output")
@click.pass_context
def vms_cmd(ctx: click.Context, as_json: bool) -> None:
    """List KubeVirt VMs + template catalog."""
    cfg = _load_cfg(ctx)
    from hypercluster.commands.vms import cmd_vms
    cmd_vms(cfg, json_mode=as_json)


@cli.group("vm")
def vm_group() -> None:
    """KubeVirt VM operations."""


@vm_group.command("create")
@click.option("--template", required=True, help="Template ID")
@click.option("--name", required=True, help="VM name")
@click.option("--namespace", default="default", help="Kubernetes namespace")
@click.option("--json", "as_json", is_flag=True, help="JSON output")
@click.pass_context
def vm_create_cmd(ctx: click.Context, template: str, name: str, namespace: str, as_json: bool) -> None:
    """Validate template and preview VM creation."""
    cfg = _load_cfg(ctx)
    from hypercluster.commands.vms import cmd_vm_create
    cmd_vm_create(cfg, template=template, name=name, namespace=namespace, json_mode=as_json)


@cli.command("workloads")
@click.option("--json", "as_json", is_flag=True, help="JSON output")
@click.pass_context
def workloads_cmd(ctx: click.Context, as_json: bool) -> None:
    """List pods and services."""
    cfg = _load_cfg(ctx)
    from hypercluster.commands.workloads import cmd_workloads
    cmd_workloads(cfg, json_mode=as_json)


@cli.group("lab")
@click.pass_context
def lab_group(ctx: click.Context) -> None:
    """Lab operations (storage, memory tune)."""


@lab_group.command("setup")
@click.pass_context
def lab_setup_cmd(ctx: click.Context) -> None:
    """Secondary disk + memory tune (from cluster.conf LAB_* vars)."""
    cfg = _load_cfg(ctx)
    from hypercluster.commands.lab import setup
    setup(cfg)


@lab_group.command("storage")
@click.pass_context
def lab_storage_cmd(ctx: click.Context) -> None:
    """Mount LAB_SECONDARY_DISK and patch storage class."""
    cfg = _load_cfg(ctx)
    from hypercluster.commands.lab import storage
    storage(cfg)


@lab_group.command("tune")
@click.pass_context
def lab_tune_cmd(ctx: click.Context) -> None:
    """Scale down HA replicas on single-node labs."""
    cfg = _load_cfg(ctx)
    from hypercluster.commands.lab import tune
    tune(cfg)


@cli.command("forge-handoff")
@click.option("--json", "as_json", is_flag=True, help="JSON output")
@click.pass_context
def forge_handoff_cmd(ctx: click.Context, as_json: bool) -> None:
    """Emit JSON handoff for Forge Day-2 import."""
    cfg = _load_cfg(ctx)
    from hypercluster.commands.forge_handoff import run
    run(cfg, json_mode=as_json)


@cli.command("unlock")
@click.pass_context
def unlock_cmd(ctx: click.Context) -> None:
    """Remove stale per-cluster lock after a crash."""
    cfg = _load_cfg(ctx)
    from hypercluster import lock
    lock.unlock_cluster(cfg.CLUSTER_NAME)


# ── entry point ────────────────────────────────────────────────────────────────

def main() -> None:
    cli(obj={})


if __name__ == "__main__":
    main()
