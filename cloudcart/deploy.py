"""Blue/green traffic shift and task-definition checks.

The shift model is SIMULATED. It is not an ECS or CodeDeploy deployment.
"""

from __future__ import annotations

import re

PLACEHOLDER_ACCOUNT = "000000000000"
ZERO_DIGEST = "sha256:" + ("0" * 64)
DIGEST = re.compile(r"@sha256:[0-9a-f]{64}$")


class Release:
    def __init__(self) -> None:
        self.production = "blue"
        self.healthy = {"blue": True, "green": False}
        self.test_listener = {"blue": False, "green": False}
        self.history: list[str] = ["blue"]

    def deploy_candidate(self, healthy: bool) -> None:
        self.healthy["green"] = healthy
        self.test_listener["green"] = True

    def shift_production(self) -> bool:
        if not self.test_listener["green"]:
            raise RuntimeError("green has no test listener")
        if not self.healthy["green"]:
            self.rollback()
            return False
        self.production = "green"
        self.history.append("green")
        return True

    def rollback(self) -> str:
        self.production = "blue"
        self.test_listener["green"] = False
        self.history.append("blue")
        return self.production


def validate_task_definition(document: dict, *, allow_placeholders: bool = False) -> list[str]:
    errors: list[str] = []
    compat = document.get("requiresCompatibilities")
    if compat != ["EC2"]:
        errors.append("task definition must use the EC2 compatibility required by the brief")
    if document.get("executionRoleArn") == document.get("taskRoleArn"):
        errors.append("execution role and task role must be different")
    containers = document.get("containerDefinitions") or []
    if not containers:
        errors.append("containerDefinitions is empty")
    for container in containers:
        image = container.get("image", "")
        if ":latest" in image or image.endswith(":latest"):
            errors.append("image uses the mutable latest tag")
        if not DIGEST.search(image):
            errors.append("image is not pinned to a sha256 digest")
        if image.endswith(ZERO_DIGEST):
            errors.append("image digest is the zero placeholder")
        if PLACEHOLDER_ACCOUNT in image and not allow_placeholders:
            errors.append("image still contains the placeholder account id")
        for item in container.get("environment") or []:
            name = item.get("name", "").lower()
            value = str(item.get("value", ""))
            if "password" in name or "secret" in name or "key" in name:
                errors.append(f"environment variable {item.get('name')} must not carry a secret")
            if value.startswith("AKIA"):
                errors.append("environment contains an access key id")
        for item in container.get("secrets") or []:
            if "valueFrom" not in item:
                errors.append("secret must be a valueFrom reference")
            if item.get("value"):
                errors.append("secret value must not be inline")
    return errors


def validate_https(status: int, headers: dict, scheme: str) -> dict:
    lowered = {str(key).lower(): str(value) for key, value in headers.items()}
    hsts = lowered.get("strict-transport-security", "")
    redirect = status in {301, 302, 307, 308}
    return {
        "hsts": hsts.startswith("max-age="),
        "hsts_value": hsts,
        "preload": "preload" in hsts.lower(),
        "http_redirects": scheme == "http" and redirect,
        "https_response": scheme == "https" and status == 200,
        "serves_plaintext_ok": scheme == "http" and status == 200,
    }


def dns_failover(primary_healthy: bool, elapsed_seconds: int, ttl_seconds: int) -> str:
    """Resolver view of a failover. Alias records still sit behind resolver caches."""

    if primary_healthy:
        return "storefront"
    if elapsed_seconds < ttl_seconds:
        return "cached-storefront"
    return "maintenance"
