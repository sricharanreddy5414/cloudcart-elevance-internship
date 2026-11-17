"""Run the local CloudCart checks and write the evidence reports.

A missing Docker daemon or a closed localhost:3000 port is recorded as a
blocker. It is not turned into a passing health check.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STACKS = [
    "task-1-route53-acm-waf",
    "task-2-secure-rds",
    "task-3-autoscaling",
    "task-4-ecs-ecr",
    "task-5-cloudfront-edge",
    "task-6-s3-storage",
]
EDGE_TESTS = [
    "application/edge-functions/edge.test.js",
]


def run(command: list[str], cwd: Path | None = None) -> dict:
    completed = subprocess.run(
        command,
        cwd=cwd or ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    return {
        "command": command,
        "cwd": str(cwd or ROOT),
        "exit_code": completed.returncode,
        "stdout": completed.stdout[-8000:],
        "stderr": completed.stderr[-8000:],
    }


def check_http() -> dict:
    try:
        with urllib.request.urlopen("http://127.0.0.1:3000/", timeout=5) as response:
            return {"status": "PASS", "http_status": response.status, "label": "LOCAL"}
    except urllib.error.HTTPError as exc:
        return {"status": "FAIL", "http_status": exc.code, "error": str(exc), "label": "LOCAL"}
    except Exception as exc:
        return {
            "status": "BLOCKED",
            "error": str(exc),
            "label": "BLOCKED",
            "note": "EverShop was not reachable from this environment. The Windows store was not modified.",
        }


def main() -> int:
    sys.path.insert(0, str(ROOT))
    started = datetime.now(timezone.utc).isoformat()
    checks = []

    test_names = [
        ".".join(path.relative_to(ROOT).with_suffix("").parts)
        for path in sorted((ROOT / "tests").rglob("test_*.py"))
    ]
    unit = run([sys.executable, "-m", "unittest", "-v", *test_names])
    checks.append({"name": "python-tests", "status": "PASS" if unit["exit_code"] == 0 else "FAIL", **unit})

    node = run(["node", "--test", *EDGE_TESTS])
    checks.append({"name": "edge-tests", "status": "PASS" if node["exit_code"] == 0 else "FAIL", **node})

    terraform = shutil.which("terraform")
    if not terraform:
        checks.append({"name": "terraform", "status": "BLOCKED", "error": "terraform is not on PATH"})
    else:
        for stack in STACKS:
            stack_dir = ROOT / "infrastructure" / "terraform" / stack
            fmt = run([terraform, "fmt", "-check", "-recursive"], cwd=stack_dir)
            init = run([terraform, "init", "-backend=false", "-input=false"], cwd=stack_dir)
            validate = run([terraform, "validate"], cwd=stack_dir)
            plan = run([terraform, "plan", "-input=false", "-lock=false", "-detailed-exitcode"], cwd=stack_dir)
            # detailed-exitcode: 0 = no changes, 2 = changes present, 1 = error.
            if validate["exit_code"] != 0 or init["exit_code"] != 0:
                status = "FAIL"
            elif plan["exit_code"] == 2:
                status = "FAIL"
                plan["stderr"] += "\nPlan proposed changes while confirm_paid_deployment is false."
            elif plan["exit_code"] not in (0, 2):
                status = "FAIL"
            else:
                status = "PASS"
            checks.append(
                {
                    "name": f"terraform-{stack}",
                    "status": status,
                    "fmt": fmt,
                    "init": init,
                    "validate": validate,
                    "plan": plan,
                }
            )

    if shutil.which("docker"):
        docker = run(["docker", "ps", "--format", "{{.Names}}"])
        checks.append({"name": "docker-ps", "status": "PASS" if docker["exit_code"] == 0 else "FAIL", **docker})
    else:
        checks.append(
            {
                "name": "docker",
                "status": "BLOCKED",
                "error": "docker is not installed in this environment",
                "label": "BLOCKED",
            }
        )

    health = check_http()
    checks.append({"name": "evershop-localhost-3000", **health})

    required = [item for item in checks if item["name"] in {"python-tests", "edge-tests"} or item["name"].startswith("terraform-")]
    failed = [item["name"] for item in required if item["status"] != "PASS"]
    blocked = [item["name"] for item in checks if item["status"] == "BLOCKED"]
    summary = {
        "generated_at": started,
        "label": "LOCAL",
        "aws_resources_created": False,
        "status": "PASS" if not failed and not blocked else ("PASS_WITH_BLOCKERS" if not failed else "FAIL"),
        "failed": failed,
        "blocked": blocked,
        "checks": checks,
    }

    evidence = ROOT / "evidence" / "test-results"
    evidence.mkdir(parents=True, exist_ok=True)
    (evidence / "validation-report.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    lines = [
        "# Validation report",
        "",
        f"Generated at {started}.",
        "",
        f"Overall status: **{summary['status']}**.",
        "",
        "No AWS resource was created by this run.",
        "",
        "| Check | Status |",
        "| --- | --- |",
    ]
    for item in checks:
        lines.append(f"| {item['name']} | {item['status']} |")
    if blocked:
        lines.extend(["", "Blocked checks are not passes. They record a missing dependency."])
    if failed:
        lines.extend(["", "Failed checks:", ""])
        for name in failed:
            lines.append(f"- {name}")
    (evidence / "validation-report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(summary["status"])
    print(f"failed={failed}")
    print(f"blocked={blocked}")
    return 0 if not failed else 1


if __name__ == "__main__":
    raise SystemExit(main())
