import io
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from tempfile import TemporaryDirectory
from urllib.parse import parse_qs, urlparse

from PIL import Image

from cloudcart.s3 import EICAR, accept_upload, presign, presign_expired, thumbnail_bytes


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

    def test_infected_upload_is_quarantined_and_not_published(self):
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            result = accept_upload(b"prefix-" + EICAR + b"-suffix", "payload.bin", root)
            self.assertEqual(result["verdict"], "infected")
            self.assertFalse(result["public"])
            self.assertFalse((root / "public" / "payload.bin").exists())
            self.assertTrue((root / "quarantine" / "payload.bin").is_file())

    def test_clean_image_gets_a_webp_thumbnail(self):
        image = Image.new("RGB", (40, 20), (10, 120, 200))
        payload = io.BytesIO()
        image.save(payload, format="PNG")
        thumb, content_type = thumbnail_bytes(payload.getvalue(), width=10)
        self.assertEqual(content_type, "image/webp")
        self.assertTrue(thumb.startswith(b"RIFF"))
        with TemporaryDirectory() as tmp:
            result = accept_upload(payload.getvalue(), "hat.png", Path(tmp))
            self.assertEqual(result["verdict"], "clean")
            self.assertTrue(result["public"])
            self.assertTrue(Path(result["thumbnail"]).is_file())


if __name__ == "__main__":
    unittest.main()
