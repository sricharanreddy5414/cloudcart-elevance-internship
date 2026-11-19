import json
import unittest
from pathlib import Path

from cloudcart.configcheck import missing_database_env, scan_tree

ROOT = Path(__file__).resolve().parents[2]


class PolicyTest(unittest.TestCase):
    def test_bucket_policy_denies_anonymous_and_plaintext(self):
        policy = json.loads((ROOT / "security" / "policies" / "product-images-bucket-policy.json").read_text(encoding="utf-8"))
        sids = {item["Sid"]: item for item in policy["Statement"]}
        self.assertEqual(sids["DenyInsecureTransport"]["Effect"], "Deny")
        self.assertEqual(sids["DenyInsecureTransport"]["Condition"]["Bool"]["aws:SecureTransport"], "false")
        self.assertEqual(sids["AllowCloudFrontRead"]["Principal"]["Service"], "cloudfront.amazonaws.com")
        self.assertIn("AWS:SourceArn", sids["AllowCloudFrontRead"]["Condition"]["StringEquals"])

    def test_iam_policies_separate_roles_and_scope_database_connect(self):
        task = json.loads((ROOT / "security" / "iam" / "task-role-policy.json").read_text(encoding="utf-8"))
        execution = json.loads((ROOT / "security" / "iam" / "execution-role-policy.json").read_text(encoding="utf-8"))
        connect = json.loads((ROOT / "security" / "iam" / "rds-connect-policy.json").read_text(encoding="utf-8"))
        task_actions = {action for item in task["Statement"] for action in item["Action"]}
        execution_actions = {action for item in execution["Statement"] for action in item["Action"]}
        self.assertIn("s3:PutObject", task_actions)
        self.assertNotIn("s3:PutObject", execution_actions)
        self.assertIn("ecr:GetAuthorizationToken", execution_actions)
        self.assertNotIn("rds-db:connect", execution_actions)
        star = [item for item in execution["Statement"] if item["Resource"] == "*"]
        self.assertEqual(star, [{
            "Sid": "EcrAuthToken",
            "Effect": "Allow",
            "Action": ["ecr:GetAuthorizationToken"],
            "Resource": "*",
        }])
        statement = connect["Statement"][0]
        self.assertEqual(statement["Action"], ["rds-db:connect"])
        self.assertNotIn("*", statement["Resource"])
        self.assertTrue(statement["Resource"].endswith("/cloudcart_iam"))

    def test_repository_scan_finds_no_access_keys(self):
        self.assertEqual(scan_tree(ROOT), [])

    def test_missing_database_env_is_reported_without_values(self):
        self.assertEqual(
            missing_database_env({"POSTGRES_USER": "postgres", "POSTGRES_PASSWORD": "", "POSTGRES_DB": "postgres"}),
            ["POSTGRES_PASSWORD"],
        )

    def test_mysql_sql_does_not_embed_a_password(self):
        sql = (ROOT / "application" / "database" / "mysql-lab" / "rds-iam-user.sql").read_text(encoding="utf-8")
        self.assertIn("AWSAuthenticationPlugin", sql)
        self.assertIn("REQUIRE SSL", sql)
        self.assertNotIn("IDENTIFIED BY", sql.upper())


if __name__ == "__main__":
    unittest.main()
