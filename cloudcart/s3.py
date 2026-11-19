"""Private image storage behaviour: presign, EICAR check, holding, thumbnails.

Presigned URLs are produced by botocore on this machine. No request is sent
to Amazon S3.

The scanner looks for the EICAR test string. A miss is `eicar-negative`.
That is not a malware clearance, and it does not approve a public object.
Only an explicit verdict of `approved` can be promoted to `public/`.
Nothing in this module emits `approved`.
"""

from __future__ import annotations

import io
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.parse import parse_qs, urlparse

import boto3
from botocore.config import Config
from PIL import Image

EICAR = b"X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*"
MAX_UPLOAD_BYTES = 5 * 1024 * 1024
PRESIGN_TTL_SECONDS = 120
SCANNER = "eicar-test-string"
PUBLIC_PREFIX = "public"


def s3_client():
    return boto3.client(
        "s3",
        region_name="ap-south-1",
        aws_access_key_id="LOCALTESTACCESSKEY",
        aws_secret_access_key="local-test-secret",
        endpoint_url="http://127.0.0.1:9",
        config=Config(signature_version="s3v4"),
    )


def presign(operation: str, bucket: str, key: str, expires_in: int = PRESIGN_TTL_SECONDS, content_type: str | None = None) -> str:
    if expires_in < 1 or expires_in > 300:
        raise ValueError("presigned URLs in this project expire within 300 seconds")
    if operation == "put_object" and not key.startswith("incoming/"):
        raise ValueError("uploads are presigned only into incoming/")
    params = {"Bucket": bucket, "Key": key}
    if operation == "put_object" and content_type:
        params["ContentType"] = content_type
    return s3_client().generate_presigned_url(operation, Params=params, ExpiresIn=expires_in)


def presign_expired(url: str, now: datetime) -> bool:
    query = parse_qs(urlparse(url).query)
    expires = int(query["X-Amz-Expires"][0])
    issued = datetime.strptime(query["X-Amz-Date"][0], "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc)
    if now.tzinfo is None:
        raise ValueError("now must be timezone-aware")
    return now >= issued + timedelta(seconds=expires)


def scan_bytes(payload: bytes) -> dict:
    """Fail closed. This function never returns a verdict that approves publication."""

    if len(payload) > MAX_UPLOAD_BYTES:
        return {
            "verdict": "rejected",
            "scanner": SCANNER,
            "reason": "exceeds-5mb",
            "approves_public": False,
        }
    if EICAR in payload:
        return {
            "verdict": "infected",
            "scanner": SCANNER,
            "reason": "eicar-test-string",
            "approves_public": False,
        }
    return {
        "verdict": "eicar-negative",
        "scanner": SCANNER,
        "reason": "no-eicar-string",
        "approves_public": False,
        "note": "Not a malware verdict. ClamAV and a signature database are not included.",
    }


def destination_key(verdict: str, name: str) -> str | None:
    if verdict == "infected":
        return f"quarantine/{name}"
    if verdict == "rejected":
        return None
    if verdict == "approved":
        return f"{PUBLIC_PREFIX}/{name}"
    if verdict in {"eicar-negative", "not-scanned"}:
        return f"holding/{name}"
    raise ValueError(f"unknown verdict {verdict}")


def promotes_to_public(verdict: str) -> bool:
    return verdict == "approved"


def thumbnail_bytes(payload: bytes, width: int = 200) -> tuple[bytes, str]:
    image = Image.open(io.BytesIO(payload))
    image = image.convert("RGB")
    ratio = width / float(image.size[0])
    height = max(1, int(image.size[1] * ratio))
    image = image.resize((width, height))
    output = io.BytesIO()
    image.save(output, format="WEBP", quality=80)
    return output.getvalue(), "image/webp"


def accept_upload(payload: bytes, name: str, root: Path) -> dict:
    decision = scan_bytes(payload)
    verdict = decision["verdict"]
    key = destination_key(verdict, name)
    public = promotes_to_public(verdict)
    result = {
        "verdict": verdict,
        "scanner": decision["scanner"],
        "public": public,
        "path": None,
        "thumbnail": None,
        "note": decision.get("note"),
    }
    if key is None:
        return result
    destination = root / key
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(payload)
    result["path"] = str(destination)
    if verdict == "eicar-negative":
        try:
            thumb, content_type = thumbnail_bytes(payload)
        except Exception:
            result["thumbnail_error"] = "not-an-image"
            return result
        thumb_path = root / "thumbnails" / f"{Path(name).stem}.webp"
        thumb_path.parent.mkdir(parents=True, exist_ok=True)
        thumb_path.write_bytes(thumb)
        result["thumbnail"] = str(thumb_path)
        result["thumbnail_type"] = content_type
    return result
