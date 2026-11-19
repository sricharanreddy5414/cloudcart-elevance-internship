# CloudCart progress

Updated: 20 November 2026 (Asia/Calcutta), after the Task 6 quarantine pipeline.

No task is complete. A task is complete only when its AWS evidence exists. None of these stacks has been applied.

| Task | Status | What was executed | What is blocked |
| --- | --- | --- | --- |
| 1 Route 53, ACM, WAF, failover | TESTED_LOCAL | Terraform validates. Plan adds nothing. Failover timing, HSTS, and redirect rules have unit tests. | No domain, no hosted zone, no certificate, no WAF. Live HTTPS and failover are BLOCKED. |
| 2 MySQL security demonstration | TESTED_LOCAL | Separate from EverShop PostgreSQL. Rotation, IAM-token lifetime, TLS rejection, and the five-minute RPO calculator have unit tests. Terraform validates. | RDS was not created. The RPO calculator is SIMULATED and sets `verified_against_rds` to false. |
| 3 Auto Scaling and chaos | TESTED_LOCAL | Mixed-capacity model, lifecycle hook, zone removal, health failure, and latency have unit tests. Terraform validates. | No Auto Scaling group. Measured availability is from the model, not from EC2. |
| 4 ECS, ECR, pipeline | TESTED_LOCAL | Digest pin, immutable ECR, EC2 capacity provider with managed scaling off, IP target groups, approval before CodeDeploy, and rollback-image selection have contract tests. Plan still adds nothing. | The image was not built here. Docker is not installed. ECR, ECS, the ALB, CodeBuild, and CodePipeline were not created. The container still runs as root. |
| 5 CloudFront and Lambda@Edge | TESTED_LOCAL | The image distribution is separate from the apex. Path, encoding, and origin-override tests pass. Terraform validates and plans no changes. | Functions are not published in us-east-1. Cache hit ratio is not a CloudFront statistic. |
| 6 S3 product images | TESTED_LOCAL | Quarantine posts, image checks, EICAR rejection, and a simulated CLEAN promotion pass. Terraform validates and plans no changes. | No bucket. The packaged worker cannot clear a file. ClamAV was not built. |

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
