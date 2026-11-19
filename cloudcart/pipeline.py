"""Quarantine-first product image pipeline.

Presigned posts are built locally and are not sent to S3. The default scanner
matches the EICAR test string only. That engine cannot emit CLEAN, so it
cannot promote an object. A caller may pass a fresh signature engine in tests.
That simulation is not a ClamAV run and not an AWS upload.
"""

from __future__ import annotations

import re
import uuid
from datetime import datetime, timedelta, timezone

from cloudcart.s3 import MAX_UPLOAD_BYTES, PRESIGN_TTL_SECONDS, s3_client

EICAR = b"X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*"
MIN_UPLOAD_BYTES = 32
MAX_EDGE_PIXELS = 4096
MAX_PIXELS = 16_000_000
MAX_SIGNATURE_AGE_HOURS = 48
PUBLIC_CACHE_CONTROL = "public, max-age=31536000, immutable"
PRODUCT_ID = re.compile(r"^[a-z0-9][a-z0-9-]{0,63}$")
VERSION = re.compile(r"^[a-z0-9][a-z0-9._-]{0,63}$")
CONTENT_TYPES = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
}
SAFE_REASONS = {
    "unsupported-type": "This file type is not accepted.",
    "invalid-image": "The file is not a readable image.",
    "too-large": "The file is too large.",
    "too-small": "The file is too small.",
    "dimensions": "The image dimensions are not allowed.",
    "malware": "The file was rejected by the scanner.",
    "scanner-unavailable": "The file could not be scanned. Try again later.",
    "stale-signatures": "The file could not be scanned. Try again later.",
    "expired": "The upload window expired.",
    "version-mismatch": "The uploaded object changed before the scan finished.",
    "destination-exists": "That image version is already published.",
}


class Principal:
    def __init__(self, subject: str, role: str, products: set[str] | None = None):
        self.subject = subject
        self.role = role
        self.products = set(products or ())


class EicarEngine:
    """Fail closed. A miss is not a malware clearance."""

    name = "eicar-test-string"
    can_clear = False
    signature_version = "eicar-standard"
    signature_age_hours = 0


class FreshSignatureEngine:
    """Test double. It is not ClamAV and it does not load a signature database."""

    def __init__(self, age_hours: float = 1, version: str = "test-signatures-1"):
        self.name = "simulated-fresh-signatures"
        self.can_clear = True
        self.signature_version = version
        self.signature_age_hours = age_hours


def public_reason(code: str) -> str:
    return SAFE_REASONS.get(code, "The file could not be processed.")


def authorize_upload(
    principal: Principal | None,
    product_id: str,
    version: str,
    content_type: str,
    content_length: int,
    *,
    bucket: str,
    now: datetime,
    upload_id: str | None = None,
) -> dict:
    if principal is None or not principal.subject:
        raise PermissionError("unauthenticated")
    if principal.role not in {"admin", "seller"}:
        raise PermissionError("forbidden")
    if not PRODUCT_ID.match(product_id or "") or not VERSION.match(version or "") or ".." in version:
        raise ValueError("invalid-product")
    if principal.role != "admin" and product_id not in principal.products:
        raise PermissionError("forbidden")
    if content_type not in CONTENT_TYPES:
        raise ValueError("unsupported-type")
    if content_length < MIN_UPLOAD_BYTES:
        raise ValueError("too-small")
    if content_length > MAX_UPLOAD_BYTES:
        raise ValueError("too-large")
    if now.tzinfo is None:
        raise ValueError("now must be timezone-aware")
    chosen = upload_id or uuid.uuid4().hex
    if not re.fullmatch(r"[a-f0-9]{32}", chosen):
        raise ValueError("invalid-upload-id")
    key = f"quarantine/{chosen}"
    extension = CONTENT_TYPES[content_type]
    filename = f"image.{extension}"
    signed = presign_quarantine_post(bucket, key, content_type)
    return {
        "upload_id": chosen,
        "status": "PENDING",
        "bucket": bucket,
        "key": key,
        "product_id": product_id,
        "version": version,
        "owner": principal.subject,
        "content_type": content_type,
        "content_length": content_length,
        "filename": filename,
        "expires_at": (now + timedelta(seconds=PRESIGN_TTL_SECONDS)).isoformat(),
        "url": signed["url"],
        "fields": signed["fields"],
    }


def presign_quarantine_post(bucket: str, key: str, content_type: str, expires_in: int = PRESIGN_TTL_SECONDS) -> dict:
    if expires_in < 1 or expires_in > 300:
        raise ValueError("presigned posts expire within 300 seconds")
    if not key.startswith("quarantine/") or ".." in key.split("/") or content_type not in CONTENT_TYPES:
        raise ValueError("uploads are presigned only into quarantine/")
    if bucket.startswith("http") or "/" in bucket or bucket in {"", "public", "rejected"}:
        raise ValueError("invalid-bucket")
    return s3_client().generate_presigned_post(
        Bucket=bucket,
        Key=key,
        Fields={"Content-Type": content_type},
        Conditions=[
            {"bucket": bucket},
            {"key": key},
            {"Content-Type": content_type},
            ["content-length-range", MIN_UPLOAD_BYTES, MAX_UPLOAD_BYTES],
        ],
        ExpiresIn=expires_in,
    )


def _png_size(payload: bytes) -> tuple[int, int] | None:
    if not payload.startswith(b"\x89PNG\r\n\x1a\n") or payload[12:16] != b"IHDR" or len(payload) < 24:
        return None
    return int.from_bytes(payload[16:20], "big"), int.from_bytes(payload[20:24], "big")


def _jpeg_size(payload: bytes) -> tuple[int, int] | None:
    if not payload.startswith(b"\xff\xd8"):
        return None
    index = 2
    while index + 9 < len(payload):
        if payload[index] != 0xFF:
            return None
        marker = payload[index + 1]
        if marker in {0xC0, 0xC1, 0xC2}:
            height = int.from_bytes(payload[index + 5 : index + 7], "big")
            width = int.from_bytes(payload[index + 7 : index + 9], "big")
            return width, height
        if marker in {0xD8, 0xD9, 0x01} or 0xD0 <= marker <= 0xD7:
            index += 2
            continue
        if index + 4 > len(payload):
            return None
        length = int.from_bytes(payload[index + 2 : index + 4], "big")
        if length < 2:
            return None
        index += 2 + length
    return None


def _webp_size(payload: bytes) -> tuple[int, int] | None:
    if len(payload) < 30 or payload[:4] != b"RIFF" or payload[8:12] != b"WEBP":
        return None
    if payload[12:16] == b"VP8X":
        return 1 + int.from_bytes(payload[24:27], "little"), 1 + int.from_bytes(payload[27:30], "little")
    if payload[12:16] == b"VP8 " and payload[23:26] == b"\x9d\x01\x2a":
        width = int.from_bytes(payload[26:28], "little") & 0x3FFF
        height = int.from_bytes(payload[28:30], "little") & 0x3FFF
        return width, height
    if payload[12:16] == b"VP8L":
        bits = int.from_bytes(payload[21:25], "little")
        return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1
    return None


def detect_type(payload: bytes) -> str | None:
    if payload.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if payload.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if len(payload) >= 12 and payload[:4] == b"RIFF" and payload[8:12] == b"WEBP":
        return "image/webp"
    return None


def validate_image(payload: bytes, declared: str) -> dict:
    if declared not in CONTENT_TYPES:
        return {"ok": False, "code": "unsupported-type"}
    if len(payload) < MIN_UPLOAD_BYTES:
        return {"ok": False, "code": "too-small"}
    if len(payload) > MAX_UPLOAD_BYTES:
        return {"ok": False, "code": "too-large"}
    actual = detect_type(payload)
    if actual is None or actual != declared:
        return {"ok": False, "code": "invalid-image"}
    size = {"image/png": _png_size, "image/jpeg": _jpeg_size, "image/webp": _webp_size}[actual](payload)
    if size is None:
        return {"ok": False, "code": "invalid-image"}
    width, height = size
    if width < 1 or height < 1 or width > MAX_EDGE_PIXELS or height > MAX_EDGE_PIXELS or width * height > MAX_PIXELS:
        return {"ok": False, "code": "dimensions"}
    return {"ok": True, "content_type": actual, "width": width, "height": height}


def scan_payload(payload: bytes | None, engine, declared: str, *, timed_out: bool = False, download_failed: bool = False) -> dict:
    if download_failed or payload is None:
        return _scan_error("scanner-unavailable", engine)
    if timed_out:
        return _scan_error("scanner-unavailable", engine)
    if engine.signature_age_hours > MAX_SIGNATURE_AGE_HOURS:
        return _scan_error("stale-signatures", engine)
    if EICAR in payload:
        return {"status": "MALICIOUS", "code": "malware", "scanner": engine.name, "signature_version": engine.signature_version}
    image = validate_image(payload, declared)
    if not image["ok"]:
        return {"status": "INVALID", "code": image["code"], "scanner": engine.name, "signature_version": engine.signature_version}
    if not engine.can_clear:
        return _scan_error("scanner-unavailable", engine)
    return {
        "status": "CLEAN",
        "code": "clean",
        "scanner": engine.name,
        "signature_version": engine.signature_version,
        "content_type": image["content_type"],
        "width": image["width"],
        "height": image["height"],
    }


def _scan_error(code: str, engine) -> dict:
    return {"status": "ERROR", "code": code, "scanner": getattr(engine, "name", "unknown"), "signature_version": getattr(engine, "signature_version", "")}


def destination_key(product_id: str, version: str, filename: str) -> str:
    if not PRODUCT_ID.match(product_id) or not VERSION.match(version) or ".." in filename or "/" in filename:
        raise ValueError("invalid-destination")
    if not re.fullmatch(r"image\.(jpg|png|webp)", filename):
        raise ValueError("invalid-destination")
    return f"public/products/{product_id}/{version}/{filename}"


def process_object(
    record: dict,
    payload: bytes | None,
    source_version: str,
    engine,
    *,
    destination_exists: bool = False,
    timed_out: bool = False,
    download_failed: bool = False,
) -> dict:
    """One scan attempt. The destination bucket and key are not taken from the object."""

    key = record.get("key", "")
    if not key.startswith("quarantine/") or ".." in key.split("/"):
        return _closed(record, "ERROR", "invalid-image")
    if record.get("status") in {"CLEAN", "MALICIOUS", "INVALID", "EXPIRED"} and record.get("source_version") == source_version:
        return dict(record)
    if record.get("source_version") and record.get("source_version") != source_version:
        return _closed(record, "ERROR", "version-mismatch")
    if record.get("status") == "EXPIRED":
        return _closed(record, "EXPIRED", "expired")
    decision = scan_payload(
        payload,
        engine,
        record.get("content_type", ""),
        timed_out=timed_out,
        download_failed=download_failed,
    )
    updated = dict(record)
    updated.update({
        "status": decision["status"],
        "code": decision["code"],
        "scanner": decision["scanner"],
        "signature_version": decision["signature_version"],
        "source_version": source_version,
        "public": False,
        "destination": None,
        "cache_control": None,
        "user_reason": public_reason(decision["code"]),
    })
    if decision["status"] != "CLEAN":
        updated["rejected_key"] = None if decision["status"] == "ERROR" else f"rejected/{record['upload_id']}"
        return updated
    if destination_exists:
        updated["status"] = "ERROR"
        updated["code"] = "destination-exists"
        updated["user_reason"] = public_reason("destination-exists")
        return updated
    target = destination_key(record["product_id"], record["version"], record["filename"])
    updated.update({
        "public": False,
        "destination": target,
        "content_type": decision["content_type"],
        "cache_control": PUBLIC_CACHE_CONTROL,
        "metadata": {"product-id": record["product_id"], "version": record["version"]},
        "acl": None,
    })
    return updated


def _closed(record: dict, status: str, code: str) -> dict:
    updated = dict(record)
    updated.update({
        "status": status,
        "code": code,
        "public": False,
        "destination": None,
        "user_reason": public_reason(code),
    })
    return updated


def lifecycle_action(key: str, age_days: int, *, current: bool, referenced: bool) -> str:
    """Local lifecycle decision. It does not call S3."""

    if key.startswith("quarantine/") and age_days >= 1:
        return "delete"
    if key.startswith("rejected/") and age_days >= 7:
        return "delete"
    if key.startswith("public/products/") and current:
        return "retain"
    if key.startswith("public/products/") and referenced:
        return "retain"
    if key.startswith("public/products/") and not current and age_days >= 90:
        return "glacier"
    if key.startswith("public/products/") and not current and age_days >= 30:
        return "standard-ia"
    return "retain"
