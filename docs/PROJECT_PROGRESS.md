# CloudCart progress

Updated: 17 November 2026 (Asia/Calcutta), after the validation run that included the CodePipeline resources.

No task is complete. A task is complete only when its AWS evidence exists. None of these stacks has been applied.

| Task | Status | What was executed | What is blocked |
| --- | --- | --- | --- |
| 1 Route 53, ACM, WAF, failover | TESTED_LOCAL | Terraform validates. Plan adds nothing. Failover timing, HSTS, and redirect rules have unit tests. | No domain, no hosted zone, no certificate, no WAF. Live HTTPS and failover are BLOCKED. |
| 2 MySQL security demonstration | TESTED_LOCAL | Separate from EverShop PostgreSQL. Rotation, IAM-token lifetime, TLS rejection, and the five-minute RPO calculator have unit tests. Terraform validates. | RDS was not created. The RPO calculator is SIMULATED and sets `verified_against_rds` to false. |
| 3 Auto Scaling and chaos | TESTED_LOCAL | Mixed-capacity model, lifecycle hook, zone removal, health failure, and latency have unit tests. Terraform validates. | No Auto Scaling group. Measured availability is from the model, not from EC2. |
| 4 ECS, ECR, pipeline | TESTED_LOCAL | Dockerfile is pinned to an image digest. Task-definition rules, blue/green shift, and rollback have unit tests. Terraform now includes CodeBuild and CodePipeline roles with the correct service principals. Plan still adds nothing. | The image was not built here. Docker is not installed in this environment. ECR, ECS, CodeBuild, and CodePipeline were not created. |
| 5 CloudFront and Lambda@Edge | TESTED_LOCAL | Query filtering, cache headers, the 1 MB WebP guard, and short-lived signed URLs pass Node tests. Pillow produced a real WebP thumbnail. Terraform validates. | Functions are not published in us-east-1. Cache hit ratio is not a CloudFront statistic. |
| 6 S3 product images | TESTED_LOCAL | Presigned URLs, quarantine, bucket policy, and lifecycle configuration are tested. Terraform validates. | No bucket. ClamAV definitions are not in the scanner. S3 Object Lambda was not called. |

Labels used in evidence: LOCAL, SIMULATED, DOCUMENTED, BLOCKED, REAL_AWS. There are no REAL_AWS results.

## Discovery

This environment does not contain the Windows Docker engine. `docker` was not on PATH. `http://127.0.0.1:3000/` refused the connection. The PostgreSQL volume was not present here, so it was not deleted. No AWS CLI call was made.

## Files that carry the implementation

- `docker-compose.yml`, `application/docker/Dockerfile`
- `cloudcart/` and `tests/`
- `application/edge-functions/`
- `application/api/server.py`
- `application/database/mysql-lab/`
- `infrastructure/terraform/task-1-route53-acm-waf/` through `task-6-s3-storage/`
- `security/iam/`, `security/policies/`, `security/malware/handler.py`
- `ci-cd/codebuild/buildspec.yml`, `ci-cd/codedeploy/appspec.yaml`, `ci-cd/codepipeline/pipeline.json`
- `scripts/run_validation.py`

## Cost

`confirm_paid_deployment` defaults to false. A plan of each stack reported no changes. Applying remains blocked by `scripts/terraform-apply.ps1`.

## Remaining work before submission

1. Confirm the AWS principal is not root, then approve any resource that would bill.
2. Build the image on the Windows Docker host without removing `postgres-data`.
3. Capture console evidence only after a real apply.
4. Record the mentor's answer on PostgreSQL versus the separate MySQL demonstration, and on whether local evidence is eligible.
5. Replace the demo script's recording with a real video under 100 MB. No video file exists yet.
