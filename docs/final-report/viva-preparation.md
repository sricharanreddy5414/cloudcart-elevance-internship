# Viva preparation

Nothing below has been deployed. If a question asks for a live result, say the check was local or not run.

## Shared answers

EverShop uses PostgreSQL. Task 2 is a separate MySQL lab because the brief names MySQL and EverShop does not run on it. The Windows volume `postgres-data` is not part of either Terraform stack.

`confirm_paid_deployment` defaults to false. A plan adds no resources. There is no live URL and no AWS evidence folder with console output.

The target is ₹0. The required services are not free. A month of the design is about ₹12,000 with GST. Current project spend is zero because nothing was created.

## Task 1

Route 53 is the DNS control the brief names. Two ACM certificates exist because CloudFront accepts only an issued certificate from `us-east-1`, while the ALB certificate must be in `ap-south-1`. HSTS is a CloudFront response-headers policy with a short max-age and no preload. Failover is a primary and secondary alias plus a health check. WAF is two web ACLs, one `CLOUDFRONT` and one `REGIONAL`, each with `AWSManagedRulesCommonRuleSet`.

A `*.cloudfront.net` name does not meet the custom-domain row. No domain is registered. Failover timing is a local TTL test, not a live DNS change.

Likely question: why two web ACLs? A CloudFront ACL and a regional ACL are different objects and cannot be shared.

## Task 2

The instance is Multi-AZ, not publicly accessible, in private subnets, with `require_secure_transport` and IAM authentication enabled. The master password is a Secrets Manager-managed secret. The IAM user and the password user are different. An IAM token lasts 15 minutes. Rotation of the password user is simulated in `cloudcart/db.py`.

Backup retention is 7 days. That configures point-in-time recovery. It does not measure a five-minute RPO. `verified_against_rds` is false. A real test reads `LatestRestorableTime` and, if a restore is approved, times a new instance.

The private route table still has no NAT and no internet route. Phase 3 adds gated interface endpoints for regional STS and Secrets Manager, plus the S3 gateway that was already there. They are not created. An IAM database token is signed on the instance from metadata credentials and does not, by itself, call STS. Say that. Do not say the endpoint was tested. Do not describe the local token function as an EC2 login.

## Task 3

The group asks for one On-Demand instance and Spot above that, across `t3.micro` and `t3.small`. The launch hook uses `ABANDON`, so a failed warm-up does not enter service. User data checks a schema version instead of running a migration on every instance. Scaling policies target CPU at 60 percent and ALB request count.

The chaos tests remove a zone inside a Python model. They do not terminate EC2 or drain an ALB. There is no load-generator result. Do not say the store had no downtime.

IMDSv2 is required on the launch template.

## Task 4

The Dockerfile and Compose file pin an image digest. ECR tag mutability is `IMMUTABLE`. ECS launch type is `EC2` until a Task 3 group ARN is supplied, and the deployment controller is `CODE_DEPLOY` with two IP target groups. CodeBuild trusts `codebuild.amazonaws.com`, not the task execution role. CodePipeline has source, build, a manual approval, and then CodeDeploy. It does not start on every commit. Blue/green rollback in `cloudcart/deploy.py` is a simulation. The container still runs as root because `USER` was not verified.

The image was not built here. Docker was missing. The artifact bucket name is no longer the zero account id. A paid apply builds `cloudcart-pipeline-<account-id>-<region>` or uses `artifact_bucket_name`. That apply has not been run.

## Task 5

The image distribution is separate from the apex. Origin Access Control does not grant public-read. The cache key is the object path. The viewer-request function rejects traversal and origin overrides, then rewrites a valid path to `public/products/...`. Transform parameters are checked and removed because no encoder is packaged. A WebP body over 1 MB is still refused by the local planner, and that planner is not associated.

The functions are not published in `us-east-1`. A cache-hit ratio has not been read from CloudFront. One local request is not a hit ratio.

## Task 6

The bucket blocks public access, enforces bucket owner, encrypts with AES256, denies non-TLS, and allows CloudFront to read only `public/*`. Lifecycle moves `public/` to Intelligent-Tiering at 30 days and Glacier at 90 days. Inventory is weekly to a second private bucket. Presigned URLs in tests expire within 300 seconds and use a local endpoint.

S3 Object Lambda is closed to new customers. The Pillow thumbnail is an ordinary object and does not satisfy that requirement. The scanner matches the EICAR test string and has no ClamAV database. An EICAR miss stays in `holding/` and is not public. Do not call either path the required service.

Glacier's minimum storage duration can cost more than leaving a lab object in Standard. Do not apply that transition for a short test without a separate approval.
