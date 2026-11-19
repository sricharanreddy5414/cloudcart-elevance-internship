"""Static checks of the local runtime files.

Category B, local integration contracts. These tests do not start Docker,
do not connect to PostgreSQL, and do not call AWS.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class RuntimeContractTest(unittest.TestCase):
    def test_root_dockerignore_is_the_build_context_file(self):
        text = (ROOT / ".dockerignore").read_text(encoding="utf-8")
        for token in (".env", "*.tfstate", "*.pem", "evidence", ".terraform"):
            self.assertIn(token, text)
        dockerfile = (ROOT / "application" / "docker" / "Dockerfile").read_text(encoding="utf-8")
        self.assertNotIn("COPY ", dockerfile)
        lowered = dockerfile.lower()
        self.assertNotIn("password=", lowered)
        self.assertNotIn("akia", lowered)

    def test_store_compose_waits_for_postgres_and_keeps_it_private(self):
        compose = (ROOT / "docker-compose.yml").read_text(encoding="utf-8")
        self.assertIn("condition: service_healthy", compose)
        self.assertIn("127.0.0.1:3000:3000", compose)
        self.assertNotIn("5432:5432", compose)
        self.assertIn("name: postgres-data", compose)
        self.assertIn("statusCode>=200&&r.statusCode<400", compose)
        self.assertNotIn(":latest", compose)

    def test_mysql_lab_is_pinned_and_does_not_use_the_store_volume(self):
        text = (ROOT / "application" / "database" / "mysql-lab" / "docker-compose.yml").read_text(encoding="utf-8")
        self.assertIn("mysql@sha256:d58ac93387f644e4e040c636b8f50494e78e5afc27ca0a87348b2f577da2b7ff", text)
        self.assertNotIn("name: postgres-data", text)
        self.assertNotIn("postgres-data:", text)
        self.assertIn("127.0.0.1:3306:3306", text)
        self.assertNotIn(":latest", text)


if __name__ == "__main__":
    unittest.main()
