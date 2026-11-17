import json
import threading
import unittest
import urllib.request

from application.api.server import serve


class PresignApiTest(unittest.TestCase):
    def test_health_and_expiring_upload_url(self):
        server = serve()
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        port = server.server_address[1]
        try:
            with urllib.request.urlopen(f"http://127.0.0.1:{port}/health") as response:
                body = json.loads(response.read().decode("utf-8"))
            self.assertEqual(body["aws"], False)
            payload = json.dumps({"bucket": "cloudcart-product-images", "key": "incoming/hat.png", "content_type": "image/png"}).encode("utf-8")
            request = urllib.request.Request(
                f"http://127.0.0.1:{port}/presign/upload",
                data=payload,
                headers={"Content-Type": "application/json"},
            )
            with urllib.request.urlopen(request) as response:
                signed = json.loads(response.read().decode("utf-8"))
            self.assertEqual(signed["label"], "LOCAL")
            self.assertIn("X-Amz-Signature", signed["url"])
            self.assertEqual(signed["expires_in"], 120)
            bad = urllib.request.Request(
                f"http://127.0.0.1:{port}/presign/upload",
                data=json.dumps({"bucket": "b", "key": "../secret"}).encode("utf-8"),
                headers={"Content-Type": "application/json"},
            )
            with self.assertRaises(urllib.error.HTTPError) as raised:
                urllib.request.urlopen(bad)
            self.assertEqual(raised.exception.code, 400)
        finally:
            server.shutdown()


if __name__ == "__main__":
    unittest.main()
