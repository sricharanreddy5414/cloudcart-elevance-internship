import importlib.util
import io
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from tempfile import TemporaryDirectory
from urllib.parse import parse_qs, urlparse

from PIL import Image

from cloudcart.s3 import EICAR, MAX_UPLOAD_BYTES, accept_upload, destination_key, presign, presign_expired, promotes_to_public, thumbnail_bytes

ROOT = Path(__file__).resolve().parents[2]


def load_handler():
    spec = importlib.util.spec_from_file_location("malware_handler", ROOT / "security" / "malware" / "handler.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ImageStorageTest(unittest.TestCase):
    def test_presigned_url_is_local_and_expires(self):
        url = presign("put_object", "cloudcart-product-images", "incoming/hat.png", content_type="image/png")
        query = parse_qs(urlparse(url).query)
        self.assertIn("X-Amz-Signature", query)
        self.assertEqual(query["X-Amz-Expires"], ["120"])
        self.assertEqual(urlparse(url).hostname, "127.0.0.1")
        issued = datetime.strptime(query["X-Amz-Date"][0], "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc)
        self.assertFalse(presign_expired(url, issued + timedelta(seconds=30)))
        self.assertTrue(presign_expired(url, issued + timedelta(seconds=121)))

    def test_presign_refuses_a_public_upload_key(self):
        with self.assertRaises(ValueError):
            presign("put_object", "cloudcart-product-images", "public/hat.png")

    def test_infected_upload_is_quarantined_and_not_published(self):
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            result = accept_upload(b"prefix-" + EICAR + b"-suffix", "payload.bin", root)
            self.assertEqual(result["verdict"], "infected")
            self.assertFalse(result["public"])
            self.assertFalse((root / "public" / "payload.bin").exists())
            self.assertTrue((root / "quarantine" / "payload.bin").is_file())

    def test_eicar_negative_image_stays_in_holding_with_a_private_thumbnail(self):
        image = Image.new("RGB", (40, 20), (10, 120, 200))
        payload = io.BytesIO()
        image.save(payload, format="PNG")
        thumb, content_type = thumbnail_bytes(payload.getvalue(), width=10)
        self.assertEqual(content_type, "image/webp")
        self.assertTrue(thumb.startswith(b"RIFF"))
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            result = accept_upload(payload.getvalue(), "hat.png", root)
            self.assertEqual(result["verdict"], "eicar-negative")
            self.assertFalse(result["public"])
            self.assertFalse((root / "public" / "hat.png").exists())
            self.assertTrue((root / "holding" / "hat.png").is_file())
            self.assertTrue(Path(result["thumbnail"]).is_file())
            self.assertNotIn("public", Path(result["thumbnail"]).parts)

    def test_oversized_object_is_rejected_and_only_approved_is_public(self):
        with TemporaryDirectory() as tmp:
            result = accept_upload(b"x" * (MAX_UPLOAD_BYTES + 1), "big.bin", Path(tmp))
        self.assertEqual(result["verdict"], "rejected")
        self.assertIsNone(result["path"])
        self.assertFalse(promotes_to_public("eicar-negative"))
        self.assertFalse(promotes_to_public("infected"))
        self.assertEqual(destination_key("approved", "hat.png"), "public/hat.png")

    def test_handler_fails_closed_without_a_body(self):
        handler = load_handler()
        missing = handler.handler({"Records": [{"s3": {"object": {"key": "incoming/hat.png"}}}]})
        self.assertEqual(missing["results"][0]["verdict"], "not-scanned")
        self.assertFalse(missing["results"][0]["public"])
        self.assertFalse(missing["production_malware_scan"])
        infected = handler.handler({"Records": [{"s3": {"object": {"key": "incoming/bad.bin"}}, "cloudcart": {"body": EICAR}}]})
        self.assertEqual(infected["results"][0]["destination"], "quarantine/bad.bin")
        self.assertFalse(infected["results"][0]["public"])


if __name__ == "__main__":
    unittest.main()
