#!/usr/bin/env python3
"""Guard compose.yml's exposure rules (issue #2, hub UPS-REPO-34, PRD NFR2).

1. Every published port binds 127.0.0.1 (never all interfaces).
2. No bare "N:N" port mapping remains in compose.yml.
3. Compose refuses to render without GRAFANA_ADMIN_PASSWORD, naming the variable.

Needs only Python 3 and `docker compose`. Run from the repo root:
    python3 scripts/check_compose.py
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COMPOSE = ROOT / "compose.yml"


def compose_config(env: dict[str, str], *extra: str) -> subprocess.CompletedProcess[str]:
    # An empty --env-file keeps a developer's local .env out of the check.
    with tempfile.NamedTemporaryFile("w", suffix=".env") as empty:
        return subprocess.run(
            ["docker", "compose", "-f", str(COMPOSE), "--env-file", empty.name, "config", *extra],
            cwd=ROOT,
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )


def main() -> int:
    failures: list[str] = []
    base = {k: v for k, v in os.environ.items() if k != "GRAFANA_ADMIN_PASSWORD"}

    bare = [
        f"compose.yml:{n}: {line.strip()}"
        for n, line in enumerate(COMPOSE.read_text().splitlines(), 1)
        if re.match(r'^\s*- "[0-9]+:[0-9]+"', line)
    ]
    if bare:
        failures.append("bare port mappings bind every interface:\n  " + "\n  ".join(bare))

    rendered = compose_config({**base, "GRAFANA_ADMIN_PASSWORD": "check-dummy"}, "--format", "json")
    if rendered.returncode != 0:
        failures.append(f"compose config failed with a password set:\n{rendered.stderr}")
    else:
        services = json.loads(rendered.stdout)["services"]
        for name, svc in sorted(services.items()):
            for port in svc.get("ports", []):
                if port.get("host_ip") != "127.0.0.1":
                    failures.append(
                        f"{name}: port {port.get('published')}->{port.get('target')} "
                        f"binds {port.get('host_ip') or 'all interfaces'}, want 127.0.0.1"
                    )

    unset = compose_config(base, "-q")
    if unset.returncode == 0:
        failures.append("compose config succeeded without GRAFANA_ADMIN_PASSWORD; Grafana would start as admin/admin")
    elif "set GRAFANA_ADMIN_PASSWORD" not in unset.stderr:
        failures.append(f"missing-password error does not name the variable:\n{unset.stderr}")

    for failure in failures:
        print(f"FAIL: {failure}", file=sys.stderr)
    if not failures:
        print("ok: all ports loopback-bound; Grafana admin password required")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
