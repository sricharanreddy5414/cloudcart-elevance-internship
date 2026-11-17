import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TF = ROOT / "infrastructure" / "terraform"


def read_stack(name: str) -> str:
    return "\n".join(path.read_text(encoding="utf-8") for path in (TF / name).glob("*.tf"))


class TerraformContractTest(unittest.TestCase):
    def test_paid_resources_are_gated(self):
        for name in (
            "task-1-route53-acm-waf",
            "task-2-secure-rds",
            "task-3-autoscaling",
            "task-4-ecs-ecr",
            "task-5-cloudfront-edge",
            "task-6-s3-storage",
        ):
            text = read_stack(name)
            self.assertIn("confirm_paid_deployment", text, name)
            self.assertIn("module.guard.resource_count", text, name)

    def test_task_one_separates_certificate_regions_and_waf_scopes(self):
        text = read_stack("task-1-route53-acm-waf")
        self.assertIn("aws.us_east_1", text)
        self.assertIn('"CLOUDFRONT"', text)
        self.assertIn('"REGIONAL"', text)
        self.assertIn('"PRIMARY"', text)
        self.assertIn('"SECONDARY"', text)
        self.assertIn("AWSManagedRulesCommonRuleSet", text)
        self.assertIn("redirect-to-https", text)
        self.assertIn("strict_transport_security", text)
        self.assertNotIn("aws_route53domains_registered_domain", text)

    def test_task_two_is_mysql_and_private(self):
        text = read_stack("task-2-secure-rds")
        self.assertIn('"mysql"', text)
        self.assertIn("multi_az", text)
        self.assertIn("publicly_accessible", text)
        self.assertIn("iam_database_authentication_enabled", text)
        self.assertIn("require_secure_transport", text)
        self.assertIn("manage_master_user_password", text)
        self.assertIn("MARIADB_AUDIT_PLUGIN", text)
        self.assertNotIn("postgres-data", text.replace("does not attach to postgres-data", ""))

    def test_task_three_mixes_purchases_and_holds_the_hook(self):
        text = read_stack("task-3-autoscaling")
        self.assertIn("on_demand_base_capacity", text)
        self.assertIn("ASGAverageCPUUtilization", text)
        self.assertIn("ALBRequestCountPerTarget", text)
        self.assertIn("autoscaling:EC2_INSTANCE_LAUNCHING", text)
        self.assertIn("ABANDON", text)

    def test_task_four_is_ecs_on_ec2_with_code_deploy(self):
        text = read_stack("task-4-ecs-ecr")
        self.assertIn('"EC2"', text)
        self.assertIn('"CODE_DEPLOY"', text)
        self.assertIn('"BLUE_GREEN"', text)
        self.assertIn("IMMUTABLE", text)
        self.assertIn("scan_on_push", text)
        self.assertIn("aws_codepipeline", text)
        self.assertIn("codebuild.amazonaws.com", text)
        self.assertIn("codepipeline.amazonaws.com", text)

    def test_task_five_uses_oac_and_a_private_origin(self):
        text = read_stack("task-5-cloudfront-edge")
        self.assertIn("aws_cloudfront_origin_access_control", text)
        self.assertIn("origin_access_control_id", text)
        self.assertNotIn("public-read", text)

    def test_task_six_locks_the_bucket(self):
        text = read_stack("task-6-s3-storage")
        self.assertIn("BucketOwnerEnforced", text)
        self.assertIn("block_public_acls", text)
        self.assertIn("INTELLIGENT_TIERING", text)
        self.assertIn("GLACIER", text)
        self.assertIn("aws_s3_bucket_inventory", text)
        self.assertIn("aws_s3_bucket_versioning", text)


if __name__ == "__main__":
    unittest.main()
