# Six-task completion matrix

Reviewed 17 November 2026 after `python3 scripts/run_validation.py` on Linux. Terraform was 1.9.8. No task is complete. Complete means the AWS evidence exists and was checked.

| Task | Requirement | In the repository | Exercised | AWS resource |
| --- | --- | --- | --- | --- |
| 1 | Domain, two ACM certificates, HTTPS, HSTS, WAF, maintenance failover | Terraform and header tests | `terraform validate` and a local HSTS/redirect test | None. BLOCKED |
| 2 | Private Multi-AZ MySQL, IAM auth, TLS, rotation, 5-minute RPO | Separate MySQL Terraform. EverShop remains PostgreSQL. Local token and rotation model | Unit tests. RPO flag `verified_against_rds=false` | None. SIMULATED |
| 3 | Mixed capacity, lifecycle hook, CPU and request scaling, zone loss | Terraform policies and `cloudcart/scaling.py` | Chaos unit tests | None. SIMULATED |
| 4 | Image, ECR, ECS on EC2, ALB, SSM, CodeBuild, CodePipeline, blue/green | Dockerfile, Compose, Terraform, `taskdef.json`, `cloudcart/deploy.py` | Contract tests. Docker build BLOCKED here | None |
| 5 | OAC, CloudFront, Lambda@Edge, cache headers, query filter, WebP, signed URL | Distribution Terraform and `application/edge-functions/` | Node tests and a Pillow WebP file. Functions are not associated in Terraform | None |
| 6 | Private bucket, ownership, encryption, presign, lifecycle, inventory, scan | Terraform, `cloudcart/s3.py`, EICAR handler | Presign, quarantine, and thumbnail tests | None. Object Lambda BLOCKED |

Overall validation status from that run: **PASS_WITH_BLOCKERS**. Python tests passed. Edge tests passed. All six stacks formatted, initialized, validated, and planned with no changes. Docker and port 3000 were blocked.
