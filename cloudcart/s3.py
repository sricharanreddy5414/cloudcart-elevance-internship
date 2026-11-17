"""Private image storage behaviour: presign, scan, quarantine, thumbnails.

Presigned URLs are produced by botocore on this machine. No request is sent
to Amazon S3. The scanner recognises the EICAR test string. It is not a
substitute for a current ClamAV database.
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


def scan_bytes(payload: bytes) -> str:
    if len(payload) > MAX_UPLOAD_BYTES:
        return "rejected"
    if EICAR in payload:
        return "infected"
    return "clean"


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
    verdict = scan_bytes(payload)
    if verdict == "infected":
        destination = root / "quarantine" / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(payload)
        return {"verdict": verdict, "public": False, "path": str(destination), "thumbnail": None}
    if verdict == "rejected":
        return {"verdict": verdict, "public": False, "path": None, "thumbnail": None}
    clean = root / "public" / name
    clean.parent.mkdir(parents=True, exist_ok=True)
    clean.write_bytes(payload)
    thumb, content_type = thumbnail_bytes(payload)
    thumb_path = root / "thumbnails" / f"{Path(name).stem}.webp"
    thumb_path.parent.mkdir(parents=True, exist_ok=True)
    thumb_path.write_bytes(thumb)
    return {
        "verdict": verdict,
        "public": True,
        "path": str(clean),
        "thumbnail": str(thumb_path),
        "thumbnail_type": content_type,
    }
