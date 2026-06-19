from __future__ import annotations

import json
import os
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Generator

import paramiko

from hypercluster import log
from hypercluster.models import ClusterConfig


@dataclass
class SSHResult:
    returncode: int
    stdout: str
    stderr: str

    @property
    def ok(self) -> bool:
        return self.returncode == 0


class SSHClient:
    def __init__(
        self,
        host: str,
        user: str,
        key_file: str | None = None,
        port: int = 22,
        connect_timeout: int = 20,
        keepalive: int = 15,
    ) -> None:
        self.host = host
        self.user = user
        self.key_file = key_file
        self.port = port
        self.connect_timeout = connect_timeout
        self.keepalive = keepalive
        self._client: paramiko.SSHClient | None = None

    def _connect(self) -> None:
        if self._client is not None:
            return
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        kwargs: dict = dict(
            hostname=self.host,
            port=self.port,
            username=self.user,
            timeout=self.connect_timeout,
            banner_timeout=30,
            auth_timeout=30,
        )
        if self.key_file:
            key_path = Path(self.key_file).expanduser()
            try:
                kwargs["pkey"] = paramiko.Ed25519Key.from_private_key_file(str(key_path))
            except paramiko.PasswordRequiredException:
                raise RuntimeError(
                    f"SSH key {key_path} requires a passphrase — "
                    "set SSH_KEY to an unencrypted key or use ssh-agent"
                )
            except paramiko.SSHException:
                try:
                    kwargs["pkey"] = paramiko.RSAKey.from_private_key_file(str(key_path))
                except paramiko.PasswordRequiredException:
                    raise RuntimeError(
                        f"SSH key {key_path} requires a passphrase — "
                        "set SSH_KEY to an unencrypted key or use ssh-agent"
                    )
                except paramiko.SSHException:
                    kwargs["key_filename"] = str(key_path)
        client.connect(**kwargs)
        transport = client.get_transport()
        if transport:
            transport.set_keepalive(self.keepalive)
        self._client = client

    def run(
        self,
        command: str,
        stdin_data: str | None = None,
        stream: bool = False,
    ) -> SSHResult:
        self._connect()
        assert self._client is not None
        stdin_fh, stdout_fh, stderr_fh = self._client.exec_command(command, timeout=None)
        if stdin_data is not None:
            stdin_fh.write(stdin_data)
            stdin_fh.channel.shutdown_write()

        if stream:
            out_lines: list[str] = []
            err_lines: list[str] = []
            chan = stdout_fh.channel
            while not chan.exit_status_ready():
                got_data = False
                if chan.recv_ready():
                    data = chan.recv(4096).decode(errors="replace")
                    sys.stdout.write(data)
                    sys.stdout.flush()
                    out_lines.append(data)
                    got_data = True
                if chan.recv_stderr_ready():
                    data = chan.recv_stderr(4096).decode(errors="replace")
                    sys.stderr.write(data)
                    sys.stderr.flush()
                    err_lines.append(data)
                    got_data = True
                if not got_data:
                    time.sleep(0.01)
            while chan.recv_ready():
                data = chan.recv(4096).decode(errors="replace")
                sys.stdout.write(data)
                out_lines.append(data)
            while chan.recv_stderr_ready():
                data = chan.recv_stderr(4096).decode(errors="replace")
                sys.stderr.write(data)
                err_lines.append(data)
            rc = chan.recv_exit_status()
            return SSHResult(rc, "".join(out_lines), "".join(err_lines))
        else:
            out = stdout_fh.read().decode(errors="replace")
            err = stderr_fh.read().decode(errors="replace")
            rc = stdout_fh.channel.recv_exit_status()
            return SSHResult(rc, out.strip(), err.strip())

    def close(self) -> None:
        if self._client:
            self._client.close()
            self._client = None

    def __enter__(self) -> "SSHClient":
        return self

    def __exit__(self, *_: object) -> None:
        self.close()


def make_client(host: str, cfg: ClusterConfig, node_overrides: dict | None = None) -> SSHClient:
    user = cfg.SSH_USER
    key = cfg.resolved_ssh_key()
    port = cfg.SSH_PORT

    if node_overrides:
        user = node_overrides.get("sshUser") or user
        k = node_overrides.get("sshKey")
        if k:
            key = str(Path(k).expanduser())
        p = node_overrides.get("sshPort")
        if p:
            port = int(p)
    elif cfg.NODE_SSH_OVERRIDES_JSON:
        try:
            overrides = json.loads(cfg.NODE_SSH_OVERRIDES_JSON)
            for o in overrides:
                if o.get("ip") == host:
                    user = o.get("sshUser") or user
                    k = o.get("sshKey")
                    if k:
                        key = str(Path(k).expanduser())
                    p = o.get("sshPort")
                    if p:
                        port = int(p)
                    break
        except (json.JSONDecodeError, TypeError):
            pass

    return SSHClient(host=host, user=user, key_file=key, port=port)


def check_connectivity(host: str, cfg: ClusterConfig) -> bool:
    try:
        with make_client(host, cfg) as c:
            result = c.run("echo ok")
            return result.ok
    except Exception:
        return False


def run_remote(host: str, cfg: ClusterConfig, command: str, stream: bool = True) -> SSHResult:
    with make_client(host, cfg) as c:
        return c.run(command, stream=stream)


def run_remote_script(host: str, cfg: ClusterConfig, script: str, stream: bool = True) -> SSHResult:
    with make_client(host, cfg) as c:
        return c.run("bash -s", stdin_data=script, stream=stream)
