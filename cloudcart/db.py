"""Task 2 controls that can be exercised without an AWS account.

IAM database authentication and Secrets Manager rotation stay separate.
A five-minute RPO is a target. A passing calculation on caller-supplied
timestamps is not a restore of an RDS instance.
"""

from __future__ import annotations

import secrets
import string
from datetime import datetime, timedelta, timezone

RPO_TARGET = timedelta(minutes=5)
IAM_TOKEN_LIFETIME = timedelta(minutes=15)


class RotationError(Exception):
    pass


class SecretStore:
    def __init__(self, current: str) -> None:
        self.versions = {"AWSCURRENT": current}

    def get(self, stage: str) -> str:
        return self.versions[stage]

    def put_pending(self, value: str) -> None:
        self.versions["AWSPENDING"] = value

    def promote(self) -> None:
        pending = self.versions.get("AWSPENDING")
        if pending is None:
            raise RotationError("no pending version")
        self.versions["AWSPREVIOUS"] = self.versions["AWSCURRENT"]
        self.versions["AWSCURRENT"] = pending
        del self.versions["AWSPENDING"]


class DatabaseUsers:
    """In-memory stand-in for the MySQL accounts under test."""

    def __init__(self) -> None:
        self.passwords: dict[str, str] = {}
        self.plugins: dict[str, str] = {}
        self.log: list[tuple] = []

    def set_password(self, user: str, password: str) -> None:
        if self.plugins.get(user) == "AWSAuthenticationPlugin":
            raise RotationError("IAM users do not take a rotated password")
        self.passwords[user] = password
        self.plugins[user] = "mysql_native_password"
        self.log.append(("set", user))

    def enable_iam(self, user: str) -> None:
        self.plugins[user] = "AWSAuthenticationPlugin"
        self.passwords.pop(user, None)
        self.log.append(("iam", user))

    def authenticate(self, user: str, secret: str, *, tls: bool) -> bool:
        self.log.append(("auth", user, tls, self.plugins.get(user, "unknown")))
        if not tls:
            return False
        if self.plugins.get(user) == "AWSAuthenticationPlugin":
            return secret.startswith("iam-token:") and not self._token_expired(secret)
        return self.passwords.get(user) == secret

    @staticmethod
    def _token_expired(secret: str) -> bool:
        marker = secret.rsplit(":", 1)[-1]
        try:
            expires = int(marker)
        except ValueError:
            return True
        return datetime.now(timezone.utc).timestamp() >= expires


def new_password(length: int = 32) -> str:
    alphabet = string.ascii_letters + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(length))


def rotate_password(store: SecretStore, database: DatabaseUsers, user: str) -> str:
    """Run the four Secrets Manager rotation steps for a password user."""

    pending = new_password()
    store.put_pending(pending)
    database.set_password(user, pending)
    if not database.authenticate(user, pending, tls=True):
        raise RotationError("new password failed over TLS")
    if database.authenticate(user, pending, tls=False):
        raise RotationError("database accepted a non-TLS login")
    store.promote()
    return store.get("AWSCURRENT")


def issue_iam_token(user: str, *, now: datetime | None = None) -> str:
    """Shape of a temporary token. This is not an RDS signature."""

    moment = now or datetime.now(timezone.utc)
    expires = int((moment + IAM_TOKEN_LIFETIME).timestamp())
    return f"iam-token:{user}:{expires}"


def token_is_expired(issued_at: datetime, now: datetime, lifetime: timedelta = IAM_TOKEN_LIFETIME) -> bool:
    if issued_at.tzinfo is None or now.tzinfo is None:
        raise ValueError("timestamps must be timezone-aware")
    return now - issued_at >= lifetime


def assess_rpo(latest_restorable: datetime, now: datetime) -> dict:
    if latest_restorable.tzinfo is None or now.tzinfo is None:
        raise ValueError("timestamps must be timezone-aware")
    lag = now - latest_restorable
    within = timedelta(0) <= lag <= RPO_TARGET
    return {
        "label": "SIMULATED",
        "verified_against_rds": False,
        "rpo_target_seconds": int(RPO_TARGET.total_seconds()),
        "lag_seconds": lag.total_seconds(),
        "within_target": within,
        "note": (
            "LatestRestorableTime within five minutes is the RDS evidence for this target. "
            "Restore duration is a different measurement and is not claimed here."
        ),
    }
