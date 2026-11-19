import shutil
import subprocess
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
        self.assertIn("origin_group", text)
        self.assertIn("aws_acm_certificate_validation", text)
        self.assertIn("rate_based_statement", text)
        self.assertIn("evaluate_target_health = false", text)
        self.assertIn("https-only", text)
        self.assertIn("AllowCloudFrontRead", text)
        self.assertNotIn("aws_route53domains_registered_domain", text)
        self.assertNotIn("preload                    = true", text)

    def test_task_two_is_mysql_and_private(self):
        text = read_stack("task-2-secure-rds")
        self.assertIn('"mysql"', text)
        self.assertIn("multi_az", text)
        self.assertIn("publicly_accessible", text)
        self.assertIn("iam_database_authentication_enabled", text)
        self.assertIn("require_secure_transport", text)
        self.assertIn("manage_master_user_password", text)
        self.assertIn("MARIADB_AUDIT_PLUGIN", text)
        self.assertIn("com.amazonaws.ap-south-1.sts", text)
        self.assertIn("private_dns_enabled", text)
        self.assertIn("sts:GetCallerIdentity", text)
        self.assertNotIn("aws_nat_gateway", text)
        self.assertNotIn('resource "aws_instance"', text)
        self.assertNotIn("postgres-data", text.replace("does not attach to postgres-data", ""))
        self.assertRegex(text, r"publicly_accessible\s*=\s*false")
        self.assertRegex(text, r"storage_encrypted\s*=\s*true")
        self.assertRegex(text, r"multi_az\s*=\s*true")
        self.assertRegex(text, r"iam_database_authentication_enabled\s*=\s*true")
        self.assertRegex(text, r"deletion_protection\s*=\s*true")
        self.assertRegex(text, r"map_public_ip_on_launch\s*=\s*false")
        self.assertIn("prevent_destroy = true", text)
        self.assertIn("rds-db:connect", text)
        self.assertIn("cloudcart_iam", text)
        self.assertIn("kms_key_id", text)
        self.assertIn("master_user_secret_kms_key_id", text)
        self.assertIn("max_allocated_storage", text)
        self.assertIn("backup_retention_days", text)
        self.assertIn("local_infile", text)
        self.assertIn("TLSv1.2,TLSv1.3", text)
        self.assertIn("RotationFailed", text)
        self.assertIn("aws_iam_instance_profile", text)
        self.assertIn("referenced_security_group_id", text)
        self.assertNotIn("0.0.0.0/0", text)
        self.assertNotRegex(text, r"from_port\s*=\s*22")
        self.assertNotIn("secret_string", text)
        self.assertNotIn("IDENTIFIED BY", text.upper())
        self.assertIn("backup_retention_days must be from 1 to 35", text)

    def test_task_two_rejects_zero_backup_retention(self):
        binary = shutil.which("terraform") or str(Path.home() / ".local" / "bin" / "terraform")
        if not Path(binary).exists():
            self.skipTest("terraform is not installed")
        result = subprocess.run(
            [binary, "plan", "-input=false", "-lock=false", "-var=backup_retention_days=0"],
            cwd=TF / "task-2-secure-rds",
            text=True,
            capture_output=True,
            check=False,
        )
        combined = result.stdout + result.stderr
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("backup_retention_days", combined)

    def test_task_three_mixes_purchases_and_holds_the_hook(self):
        text = read_stack("task-3-autoscaling")
        self.assertIn("on_demand_base_capacity", text)
        self.assertIn("ASGAverageCPUUtilization", text)
        self.assertIn("ALBRequestCountPerTarget", text)
        self.assertIn("autoscaling:EC2_INSTANCE_LAUNCHING", text)
        self.assertIn("ABANDON", text)
        userdata = (TF / "task-3-autoscaling" / "userdata.sh").read_text(encoding="utf-8")
        self.assertIn("record-lifecycle-action-heartbeat", userdata)
        self.assertIn("finish ABANDON", userdata)
        self.assertIn("finish CONTINUE", userdata)
        self.assertLess(userdata.index("finish CONTINUE"), userdata.index("systemctl start ecs"))
        self.assertIn("ECS_ENABLE_SPOT_INSTANCE_DRAINING=true", userdata)
        self.assertIn("autoscaling:EC2_INSTANCE_TERMINATING", text)
        self.assertIn("capacity_rebalance", text)
        self.assertIn("capacity-optimized", text)
        self.assertRegex(text, r'http_tokens\s*=\s*"required"')
        self.assertRegex(text, r"http_put_response_hop_limit\s*=\s*1")
        self.assertRegex(text, r"encrypted\s*=\s*true")
        self.assertIn("t3.small", text)
        self.assertNotIn("t3.micro", text)
        self.assertNotIn("t4g.", text)
        self.assertIn("desired_capacity must sit between min_size and max_size", text)
        self.assertIn("AmazonEC2ContainerServiceforEC2Role", text)
        self.assertIn("ssm:GetParameter", text)
        self.assertIn("autoscaling:CompleteLifecycleAction", text)
        self.assertIn("schema_version", text)
        self.assertNotIn("0.0.0.0/0", text)
        self.assertNotRegex(text, r"from_port\s*=\s*22")
        self.assertNotIn("secret_string", text)
        self.assertRegex(text, r'health_check_type\s*=\s*"EC2"')

    def test_task_three_rejects_desired_above_maximum(self):
        binary = shutil.which("terraform") or str(Path.home() / ".local" / "bin" / "terraform")
        if not Path(binary).exists():
            self.skipTest("terraform is not installed")
        result = subprocess.run(
            [binary, "plan", "-input=false", "-lock=false", "-var=desired_capacity=9"],
            cwd=TF / "task-3-autoscaling",
            text=True,
            capture_output=True,
            check=False,
        )
        combined = result.stdout + result.stderr
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("desired_capacity", combined)

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
        self.assertNotIn("cloudcart-pipeline-artifacts-000000000000", text)
        self.assertIn("artifact_bucket_name", text)
        self.assertIn("aws_s3_bucket_versioning", text)
        self.assertIn("referenced_security_group_id", text)
        self.assertIn("cloudcart-tasks", text)
        self.assertIn("com.amazonaws.global.cloudfront.origin-facing", text)
        self.assertIn("ELBSecurityPolicy-TLS13-1-2-2021-06", text)
        self.assertIn("alb_certificate_arn", text)
        self.assertIn('target_type = "ip"', text)
        self.assertIn("imageCountMoreThan", text)
        self.assertIn("ManualApproval", text)
        self.assertRegex(text, r'status\s*=\s*"DISABLED"')
        self.assertRegex(text, r'managed_termination_protection\s*=\s*"DISABLED"')
        self.assertIn("schema_version", text)
        self.assertIn("5432", text)
        self.assertNotIn("3306", text)
        self.assertNotIn("AWSCodeDeployRoleForECS", text)
        self.assertIn("PassTaskRoles", text)
        self.assertIn("@sha256", text)

    def test_task_four_rejects_a_mutable_image_tag(self):
        binary = shutil.which("terraform") or str(Path.home() / ".local" / "bin" / "terraform")
        if not Path(binary).exists():
            self.skipTest("terraform is not installed")
        result = subprocess.run(
            [
                binary,
                "plan",
                "-input=false",
                "-lock=false",
                "-var=image_uri=000000000000.dkr.ecr.ap-south-1.amazonaws.com/cloudcart:latest",
            ],
            cwd=TF / "task-4-ecs-ecr",
            text=True,
            capture_output=True,
            check=False,
        )
        combined = result.stdout + result.stderr
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("image_uri", combined)

    def test_task_five_uses_oac_and_a_private_origin(self):
        text = read_stack("task-5-cloudfront-edge")
        self.assertIn("aws_cloudfront_origin_access_control", text)
        self.assertIn("origin_access_control_id", text)
        self.assertIn("image_viewer_request_qualified_arn", text)
        self.assertNotIn("public-read", text)
        self.assertIn('query_string_behavior = "none"', text)
        self.assertIn("edgelambda.amazonaws.com", text)
        self.assertIn("viewer-request", text)
        self.assertIn("PriceClass_200", text)
        self.assertIn("^images[.]", text)
        self.assertNotIn("Authorization", text)
        self.assertNotIn("secretsmanager", text)
        self.assertNotIn('target_origin_id       = "alb"', text)

    def test_task_five_rejects_an_apex_alias(self):
        binary = shutil.which("terraform") or str(Path.home() / ".local" / "bin" / "terraform")
        if not Path(binary).exists():
            self.skipTest("terraform is not installed")
        result = subprocess.run(
            [binary, "plan", "-input=false", "-lock=false", "-var=image_aliases=[\"example.invalid\"]"],
            cwd=TF / "task-5-cloudfront-edge",
            text=True,
            capture_output=True,
            check=False,
        )
        combined = result.stdout + result.stderr
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("image_aliases", combined)

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
