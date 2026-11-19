# Six-task completion matrix

Updated 19 November 2026 (Asia/Calcutta). A row is complete only when its status is AWS TESTED and EVIDENCE COMPLETE. No row is there.

Status words: NOT STARTED, CODE READY, LOCALLY VALIDATED, COST REVIEW REQUIRED, AWAITING APPROVAL, AWS DEPLOYED, AWS TESTED, EVIDENCE COMPLETE, TERMINATED AFTER EVIDENCE, BLOCKED.

| Task | Requirement | What exists | Status |
| --- | --- | --- | --- |
| 1 | Route 53 custom domain | Terraform hosted zone. No domain is registered. | BLOCKED |
| 1 | ACM in us-east-1 and in ap-south-1 | Two certificate resources, DNS validation records. Count is zero until approval. | COST REVIEW REQUIRED |
| 1 | HTTPS, HSTS, maintenance failover | CloudFront redirect, HSTS policy, primary and secondary records. Header rules have a local test. | LOCALLY VALIDATED |
| 1 | WAF managed rules on CloudFront and ALB | Two web ACLs with `AWSManagedRulesCommonRuleSet`. | COST REVIEW REQUIRED |
| 2 | Private Multi-AZ MySQL, no public access | Separate from EverShop PostgreSQL. Subnets have no internet route. | COST REVIEW REQUIRED |
| 2 | IAM database authentication and TLS | `iam_database_authentication_enabled` and `require_secure_transport`. Token lifetime is a local model. | LOCALLY VALIDATED |
| 2 | Secrets Manager rotation | Master password is managed by Secrets Manager in Terraform. The four rotation steps are simulated in `cloudcart/db.py`. | LOCALLY VALIDATED |
| 2 | EC2 IAM token and five-minute RPO | No EC2 client and no restore. `verified_against_rds` is false. | BLOCKED |
| 3 | Mixed On-Demand and Spot, lifecycle hook | Launch template, mixed policy, hook, CPU and ALB request policies. | COST REVIEW REQUIRED |
| 3 | Termination and Availability Zone tests | In-process model in `tests/chaos/test_chaos.py`. Not an EC2 termination. | LOCALLY VALIDATED |
| 4 | EverShop image, ECR, ECS on EC2, ALB | Dockerfile and Compose pin a digest. Terraform defines the service, ALB, and immutable ECR. | CODE READY |
| 4 | SSM, CodeBuild, CodePipeline, blue/green | Parameter Store names, CodeBuild role, CodePipeline, CodeDeploy blue/green. Rollback is simulated. Docker is not available in the Phase 1 environment. | LOCALLY VALIDATED |
| 5 | Private S3 origin and OAC | Distribution and origin access control. No public-read grant. | COST REVIEW REQUIRED |
| 5 | Lambda@Edge, query filter, WebP, signed URLs | Node functions pass local tests. They are not published in us-east-1 and are not associated with the distribution. | LOCALLY VALIDATED |
| 5 | Cache-hit ratio | No CloudFront statistic has been read. | BLOCKED |
| 6 | Private bucket, owner enforced, encryption, presign | Bucket controls in Terraform. Presign test uses a local endpoint. | LOCALLY VALIDATED |
| 6 | Intelligent-Tiering, Glacier, inventory | Lifecycle and weekly inventory resources. Glacier has a 90-day minimum charge if applied. | COST REVIEW REQUIRED |
| 6 | CloudFront delivery of images | Reuses the Task 5 origin. Not deployed. | COST REVIEW REQUIRED |
| 6 | S3 Object Lambda thumbnails | Not implemented. New customers cannot start the service. Pillow thumbnails are ordinary objects and do not satisfy this row. | BLOCKED |
| 6 | Lambda and ClamAV scanning | EICAR string match only. No ClamAV signature database. | BLOCKED |

EverShop PostgreSQL and the `postgres-data` volume are not part of Task 2.
