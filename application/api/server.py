"""Local presign service.

The process creates SigV4 query strings with botocore and does not contact
Amazon S3. Bind it to 127.0.0.1 on an ephemeral port.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from cloudcart.pipeline import authorize_upload
from cloudcart.s3 import presign


class Handler(BaseHTTPRequestHandler):
    authorizer = None
    bucket = "cloudcart-product-images"
    def do_GET(self):
        if self.path != "/health":
            self._send(404, {"error": "not found"})
            return
        self._send(200, {"status": "ok", "service": "cloudcart-presign", "aws": False})

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length else b"{}"
        try:
            body = json.loads(raw.decode("utf-8"))
        except json.JSONDecodeError:
            self._send(400, {"error": "invalid json"})
            return
        if self.path == "/uploads":
            self._authorize_upload(body)
            return
        if self.path not in {"/presign/upload", "/presign/download"}:
            self._send(404, {"error": "not found"})
            return
        bucket = body.get("bucket")
        key = body.get("key")
        if not bucket or not key or key.startswith("/") or ".." in key.split("/"):
            self._send(400, {"error": "invalid object key"})
            return
        try:
            if self.path.endswith("upload"):
                url = presign("put_object", bucket, key, content_type=body.get("content_type", "application/octet-stream"))
            else:
                url = presign("get_object", bucket, key)
        except ValueError as exc:
            self._send(400, {"error": str(exc)})
            return
        self._send(200, {"url": url, "expires_in": 120, "label": "LOCAL"})

    def _authorize_upload(self, body):
        principal = None
        if self.authorizer is not None:
            principal = self.authorizer.authenticate(self.headers.get("X-CloudCart-Token", ""))
        try:
            grant = authorize_upload(
                principal,
                body.get("product_id", ""),
                body.get("version", ""),
                body.get("content_type", ""),
                int(body.get("content_length", 0)),
                bucket=self.bucket,
                now=datetime.now(timezone.utc),
            )
        except PermissionError as exc:
            status = 401 if str(exc) == "unauthenticated" else 403
            self._send(status, {"error": str(exc)})
            return
        except (ValueError, TypeError):
            self._send(400, {"error": "invalid upload"})
            return
        self._send(200, {
            "upload_id": grant["upload_id"],
            "key": grant["key"],
            "url": grant["url"],
            "fields": grant["fields"],
            "expires_at": grant["expires_at"],
            "status": grant["status"],
            "label": "LOCAL",
        })

    def log_message(self, fmt, *args):
        return

    def _send(self, status, payload):
        data = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


def serve(host: str = "127.0.0.1", port: int = 0, authorizer=None, bucket: str = "cloudcart-product-images") -> ThreadingHTTPServer:
    bound = type("BoundHandler", (Handler,), {"authorizer": authorizer, "bucket": bucket})
    return ThreadingHTTPServer((host, port), bound)
