import io
import json
import struct
import threading
import unittest
import urllib.error
import urllib.request
from datetime import datetime, timezone
from urllib.parse import parse_qs, urlparse

from PIL import Image

from application.api.server import serve
from cloudcart.pipeline import (
    EicarEngine,
    FreshSignatureEngine,
    MAX_UPLOAD_BYTES,
    Principal,
    authorize_upload,
    destination_key,
    lifecycle_action,
    process_object,
    validate_image,
)
from cloudcart.s3 import EICAR
from security.malware import scan_worker

NOW = datetime(2026, 11, 20, tzinfo=timezone.utc)
BUCKET = "cloudcart-product-images"


def png_bytes(width=32, height=16):
    buffer = io.BytesIO()
    Image.new("RGB", (width, height), (20, 40, 60)).save(buffer, format="PNG")
    return buffer.getvalue()


def jpeg_bytes():
    buffer = io.BytesIO()
    Image.new("RGB", (32, 16), (200, 10, 10)).save(buffer, format="JPEG")
    return buffer.getvalue()


def webp_bytes():
    buffer = io.BytesIO()
    Image.new("RGB", (32, 16), (10, 80, 20)).save(buffer, format="WEBP")
    return buffer.getvalue()


def bomb_png():
    header = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", 100_000, 100_000, 8, 2, 0, 0, 0)
    return header + struct.pack(">I", 13) + b"IHDR" + ihdr + b"\x00" * 32


class TokenAuthorizer:
    def __init__(self, tokens):
        self.tokens = tokens

    def authenticate(self, token):
        return self.tokens.get(token)


def record():
    seller = Principal("seller-1", "seller", {"hat"})
    return authorize_upload(seller, "hat", "v1", "image/png", 400, bucket=BUCKET, now=NOW)


class PipelineTest(unittest.TestCase):
    def test_seller_receives_a_quarantine_post_and_cannot_choose_the_key(self):
        grant = record()
        self.assertTrue(grant["key"].startswith("quarantine/"))
        self.assertNotIn("public/", grant["key"])
        self.assertEqual(grant["fields"]["key"], grant["key"])
        self.assertEqual(grant["fields"]["Content-Type"], "image/png")
        self.assertNotIn("local-test-secret", json.dumps(grant["fields"]))
        policy = grant["fields"]["policy"]
        self.assertTrue(policy)
        with self.assertRaises(PermissionError):
            authorize_upload(None, "hat", "v1", "image/png", 400, bucket=BUCKET, now=NOW)
        stranger = Principal("seller-2", "seller", {"other"})
        with self.assertRaises(PermissionError):
            authorize_upload(stranger, "hat", "v1", "image/png", 400, bucket=BUCKET, now=NOW)
        with self.assertRaises(ValueError):
            authorize_upload(Principal("seller-1", "seller", {"hat"}), "../hat", "v1", "image/png", 400, bucket=BUCKET, now=NOW)
        with self.assertRaises(ValueError):
            authorize_upload(Principal("seller-1", "seller", {"hat"}), "hat", "v1", "image/svg+xml", 400, bucket=BUCKET, now=NOW)
        with self.assertRaises(ValueError):
            authorize_upload(Principal("seller-1", "seller", {"hat"}), "hat", "v1", "image/png", MAX_UPLOAD_BYTES + 1, bucket=BUCKET, now=NOW)

    def test_image_bytes_must_match_the_declared_type_and_size(self):
        self.assertTrue(validate_image(png_bytes(), "image/png")["ok"])
        self.assertTrue(validate_image(jpeg_bytes(), "image/jpeg")["ok"])
        self.assertTrue(validate_image(webp_bytes(), "image/webp")["ok"])
        self.assertEqual(validate_image(jpeg_bytes(), "image/png")["code"], "invalid-image")
        self.assertEqual(validate_image(b"<svg xmlns='http://www.w3.org/2000/svg'></svg>" + b"\x00" * 20, "image/png")["code"], "invalid-image")
        self.assertEqual(validate_image(b"not-an-image" + b"\x00" * 40, "image/jpeg")["code"], "invalid-image")
        self.assertEqual(validate_image(bomb_png(), "image/png")["code"], "dimensions")
        self.assertEqual(validate_image(b"\x89PNG\r\n\x1a\n" + b"short", "image/png")["code"], "too-small")

    def test_only_a_fresh_clean_scan_promotes_the_task_five_key(self):
        body = png_bytes()
        granted = record()
        clean = process_object(granted, body, "version-1", FreshSignatureEngine())
        self.assertEqual(clean["status"], "CLEAN")
        self.assertEqual(clean["destination"], "public/products/hat/v1/image.png")
        self.assertEqual(clean["cache_control"], "public, max-age=31536000, immutable")
        self.assertEqual(clean["content_type"], "image/png")
        self.assertIsNone(clean["acl"])
        self.assertNotIn("exif", clean["metadata"])
        again = process_object(clean, body, "version-1", FreshSignatureEngine())
        self.assertEqual(again["destination"], clean["destination"])
        mismatch = process_object(clean, body, "version-2", FreshSignatureEngine())
        self.assertEqual(mismatch["status"], "ERROR")
        self.assertIsNone(mismatch["destination"])
        taken = process_object(granted, body, "version-9", FreshSignatureEngine(), destination_exists=True)
        self.assertEqual(taken["code"], "destination-exists")
        self.assertIsNone(taken["destination"])

    def test_eicar_errors_and_bad_files_do_not_promote(self):
        granted = record()
        infected = bytearray(png_bytes())
        infected.extend(EICAR)
        malicious = process_object(granted, bytes(infected), "version-1", FreshSignatureEngine())
        self.assertEqual(malicious["status"], "MALICIOUS")
        self.assertIsNone(malicious["destination"])
        self.assertTrue(malicious["rejected_key"].startswith("rejected/"))
        invalid = process_object(granted, b"not-an-image-at-all" + b"x" * 40, "version-1", FreshSignatureEngine())
        self.assertEqual(invalid["status"], "INVALID")
        self.assertIsNone(invalid["destination"])
        for kwargs in ({"timed_out": True}, {"download_failed": True}):
            failed = process_object(granted, png_bytes(), "version-1", FreshSignatureEngine(), **kwargs)
            self.assertEqual(failed["status"], "ERROR")
            self.assertIsNone(failed["destination"])
        stale = process_object(granted, png_bytes(), "version-1", FreshSignatureEngine(age_hours=72))
        self.assertEqual(stale["code"], "stale-signatures")
        self.assertIsNone(stale["destination"])
        closed = process_object(granted, png_bytes(), "version-1", EicarEngine())
        self.assertEqual(closed["status"], "ERROR")
        self.assertIsNone(closed["destination"])
        self.assertIn("could not be scanned", closed["user_reason"])

    def test_worker_cannot_clear_and_lifecycle_keeps_current_images(self):
        event = {"Records": [{"cloudcart": {"upload_id": "a" * 32, "key": "quarantine/" + "a" * 32, "product_id": "hat", "version": "v1", "filename": "image.png", "content_type": "image/png", "body": png_bytes(), "source_version": "version-1"}}]}
        result = scan_worker.handler(event)
        self.assertFalse(result["can_clear"])
        self.assertFalse(result["results"][0]["promoted"])
        self.assertIsNone(result["results"][0]["destination"])
        self.assertEqual(lifecycle_action("quarantine/abc", 1, current=True, referenced=False), "delete")
        self.assertEqual(lifecycle_action("rejected/abc", 7, current=True, referenced=False), "delete")
        self.assertEqual(lifecycle_action("public/products/hat/v1/image.png", 400, current=True, referenced=True), "retain")
        self.assertEqual(lifecycle_action("public/products/hat/old/image.png", 100, current=False, referenced=False), "glacier")
        self.assertEqual(destination_key("hat", "v1", "image.png"), "public/products/hat/v1/image.png")
        with self.assertRaises(ValueError):
            destination_key("hat", "..", "image.png")

    def test_upload_route_requires_the_seller_and_ignores_a_caller_bucket(self):
        authorizer = TokenAuthorizer({"seller-token": Principal("seller-1", "seller", {"hat"})})
        server = serve(authorizer=authorizer)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        port = server.server_address[1]
        try:
            missing = urllib.request.Request(
                f"http://127.0.0.1:{port}/uploads",
                data=json.dumps({"product_id": "hat", "version": "v1", "content_type": "image/png", "content_length": 400}).encode("utf-8"),
                headers={"Content-Type": "application/json"},
            )
            with self.assertRaises(urllib.error.HTTPError) as raised:
                urllib.request.urlopen(missing)
            self.assertEqual(raised.exception.code, 401)
            request = urllib.request.Request(
                f"http://127.0.0.1:{port}/uploads",
                data=json.dumps({
                    "product_id": "hat",
                    "version": "v1",
                    "content_type": "image/png",
                    "content_length": 400,
                    "bucket": "other-bucket",
                    "key": "public/products/hat/v1/evil.png",
                }).encode("utf-8"),
                headers={"Content-Type": "application/json", "X-CloudCart-Token": "seller-token"},
            )
            with urllib.request.urlopen(request) as response:
                body = json.loads(response.read().decode("utf-8"))
            self.assertTrue(body["key"].startswith("quarantine/"))
            self.assertNotIn("other-bucket", body["url"])
            self.assertNotIn("evil.png", body["key"])
            parsed = urlparse(body["url"])
            self.assertEqual(parsed.hostname, "127.0.0.1")
            self.assertEqual(parse_qs(parsed.query).get("X-Amz-Expires"), None)
        finally:
            server.shutdown()


if __name__ == "__main__":
    unittest.main()
