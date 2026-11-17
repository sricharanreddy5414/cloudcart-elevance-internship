import unittest
from pathlib import Path

from cloudcart.deploy import Release, dns_failover, validate_https, validate_task_definition


ROOT = Path(__file__).resolve().parents[2]


class DeployTest(unittest.TestCase):
    def test_unhealthy_green_rolls_back_to_blue(self):
        release = Release()
        release.deploy_candidate(False)
        self.assertFalse(release.shift_production())
        self.assertEqual(release.production, "blue")

    def test_healthy_green_takes_production_traffic(self):
        release = Release()
        release.deploy_candidate(True)
        self.assertTrue(release.shift_production())
        self.assertEqual(release.production, "green")
        self.assertEqual(release.rollback(), "blue")

    def test_task_definition_rejects_latest_and_inline_secrets(self):
        errors = validate_task_definition(
            {
                "requiresCompatibilities": ["EC2"],
                "executionRoleArn": "arn:aws:iam::123456789012:role/exec",
                "taskRoleArn": "arn:aws:iam::123456789012:role/exec",
                "containerDefinitions": [
                    {
                        "image": "evershop/evershop:latest",
                        "environment": [{"name": "DB_PASSWORD", "value": "secret"}],
                        "secrets": [{"name": "TOKEN", "value": "inline"}],
                    }
                ],
            }
        )
        self.assertGreaterEqual(len(errors), 3)

    def test_pinned_task_definition_is_accepted(self):
        digest = "a" * 64
        errors = validate_task_definition(
            {
                "requiresCompatibilities": ["EC2"],
                "executionRoleArn": "arn:aws:iam::123456789012:role/exec",
                "taskRoleArn": "arn:aws:iam::123456789012:role/task",
                "containerDefinitions": [
                    {
                        "image": f"123456789012.dkr.ecr.ap-south-1.amazonaws.com/cloudcart@sha256:{digest}",
                        "environment": [{"name": "DB_HOST", "value": "db.internal"}],
                        "secrets": [{"name": "DB_PASSWORD", "valueFrom": "arn:aws:secretsmanager:ap-south-1:123456789012:secret:db"}],
                    }
                ],
            }
        )
        self.assertEqual(errors, [])

    def test_hsts_and_redirect_rules(self):
        headers = {"Strict-Transport-Security": "max-age=300; includeSubDomains"}
        https = validate_https(200, headers, "https")
        http = validate_https(301, headers, "http")
        leaked = validate_https(200, headers, "http")
        self.assertTrue(https["hsts"])
        self.assertFalse(https["preload"])
        self.assertTrue(http["http_redirects"])
        self.assertTrue(leaked["serves_plaintext_ok"])

    def test_failover_waits_for_ttl(self):
        self.assertEqual(dns_failover(True, 0, 60), "storefront")
        self.assertEqual(dns_failover(False, 10, 60), "cached-storefront")
        self.assertEqual(dns_failover(False, 60, 60), "maintenance")

    def test_compose_and_dockerfile_do_not_publish_the_database_or_use_latest(self):
        compose = (ROOT / "docker-compose.yml").read_text(encoding="utf-8")
        dockerfile = (ROOT / "application" / "docker" / "Dockerfile").read_text(encoding="utf-8")
        cleanup = (ROOT / "scripts" / "cleanup-local.ps1").read_text(encoding="utf-8")
        self.assertIn("127.0.0.1:3000:3000", compose)
        self.assertIn("name: postgres-data", compose)
        self.assertIn("name: myevershop", compose)
        self.assertNotIn("5432:5432", compose)
        self.assertNotIn(":latest", compose)
        self.assertNotIn(":latest", dockerfile)
        self.assertIn("evershop/evershop@${EVERSHOP_DIGEST}", dockerfile)
        self.assertIn("sha256:385934128c115f0ea92df17f5d70998532208d4a94b9b6b28149af74b5b3f6b2", dockerfile)
        self.assertIn("HEALTHCHECK", dockerfile)
        self.assertIn("postgres-data", cleanup)
        self.assertIn("Refuse", cleanup)


if __name__ == "__main__":
    unittest.main()
