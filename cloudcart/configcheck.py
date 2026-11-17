"""File and environment checks that do not print secret values."""

from __future__ import annotations

import os
import re
from pathlib import Path

SECRET_PATTERNS = (
    re.compile(r"AKIA[0-9A-Z]{16}"),
    re.compile(r"-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----"),
    re.compile(r"aws_secret_access_key\s*=\s*['\"][A-Za-z0-9/+=]{20,}"),
)

SKIP_DIRS = {".git", "node_modules", ".terraform", "__pycache__", ".venv"}


def missing_database_env(env: dict | None = None) -> list[str]:
    source = os.environ if env is None else env
    return [name for name in ("POSTGRES_USER", "POSTGRES_PASSWORD", "POSTGRES_DB") if not source.get(name)]


def scan_tree(root: Path) -> list[str]:
    findings = []
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        if path.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp", ".zip"}:
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for pattern in SECRET_PATTERNS:
            if pattern.search(text):
                findings.append(str(path.relative_to(root)))
                break
    return findings
