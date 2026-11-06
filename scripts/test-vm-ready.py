#!/usr/bin/env python3
"""Quietly wait for the test VM's SSH, VNC/noVNC and MCP services."""

import json
import os
import socket
import subprocess
import sys
import time
import urllib.request


def ssh_ready():
    subprocess.run(
        ["ssh", "-p", "2222", "-o", "BatchMode=yes", "-o", "ConnectTimeout=2",
         "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
         "root@127.0.0.1", "true"],
        check=True, timeout=3, stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )


def vnc_ready():
    with socket.create_connection(("127.0.0.1", 5950), timeout=2) as connection:
        with connection.makefile("rb") as stream:
            banner = stream.read(12)
            if not (banner.startswith(b"RFB ") and banner.endswith(b"\n")):
                raise ValueError("Missing VNC protocol banner")
    with urllib.request.urlopen("http://127.0.0.1:6080/vnc.html", timeout=2) as response:
        response.read(1)


def mcp_ready(port):
    url = f"http://127.0.0.1:{port}/mcp"
    headers = {"Content-Type": "application/json", "Accept": "application/json, text/event-stream"}
    body = {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {
        "protocolVersion": "2025-03-26", "capabilities": {},
        "clientInfo": {"name": "test-vm-ready", "version": "1.0"},
    }}
    session = None
    try:
        request = urllib.request.Request(url, json.dumps(body).encode(), headers)
        with urllib.request.urlopen(request, timeout=2) as response:
            session = response.headers.get("Mcp-Session-Id")
            if "text/event-stream" in response.headers.get("Content-Type", ""):
                result = None
                for line in response:
                    if line.startswith(b"data:"):
                        message = json.loads(line[5:])
                        if message.get("id") == 1:
                            result = message
                            break
            else:
                result = json.load(response)
            if not isinstance(result, dict) or not result.get("result", {}).get("protocolVersion"):
                raise ValueError("MCP initialization failed")
    finally:
        if session:
            headers["Mcp-Session-Id"] = session
            headers["MCP-Protocol-Version"] = "2025-03-26"
            try:
                with urllib.request.urlopen(urllib.request.Request(url, headers=headers, method="DELETE"), timeout=2):
                    pass
            except OSError:
                pass  # Some servers do not support client-initiated session deletion.


def wait_ready(pids, timeout=180):
    checks = {"SSH": ssh_ready, "VNC/noVNC": vnc_ready,
              "Hypruse MCP": lambda: mcp_ready(8081), "NixOS MCP": lambda: mcp_ready(8082)}
    deadline = time.monotonic() + timeout
    while True:
        for pid in pids:
            os.kill(pid, 0)
        pending = []
        for name, check in checks.items():
            try:
                check()
            except (OSError, ValueError, subprocess.SubprocessError):
                pending.append(name)
        if not pending:
            return
        if time.monotonic() >= deadline:
            raise TimeoutError("Timed out waiting for: " + ", ".join(pending))
        time.sleep(1)


if __name__ == "__main__":
    try:
        wait_ready([int(pid) for pid in sys.argv[1:]])
    except (OSError, ValueError) as error:
        sys.exit(f"VM startup failed: {error}. See /tmp/test-vm-console.log and /tmp/test-vm-novnc.log")
