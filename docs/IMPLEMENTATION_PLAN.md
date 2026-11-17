# Implementation record

This is the work that was done, and the work that still needs an AWS account decision. It is not a request to create resources.

## What was preserved

The EverShop database volume was not on this machine. Nothing ran `docker compose down`, and nothing deleted a volume. The Compose file binds the store to `127.0.0.1:3000`, keeps PostgreSQL on the Docker network, and names the volume `postgres-data`.

EverShop stays on PostgreSQL. Task 2 is a separate MySQL design and a local security harness. The two are not described as the same database.

## What was implemented

1. An immutable EverShop image reference. The Docker Hub index digest for `evershop/evershop` was read on 17 November 2026: `sha256:385934128c115f0ea92df17f5d70998532208d4a94b9b6b28149af74b5b3f6b2`. PostgreSQL 16 index digest: `sha256:dd2bf3ce2dc83a81674cf7f217fcfd8a5009a4b325dda5b843bfee82a06cff6f`.
2. Six Terraform stacks. Each resource is created only when `confirm_paid_deployment` is true. The default plan adds nothing.
3. Local tests for presigned URLs, malware quarantine, WebP thumbnails, query filtering, signed URLs, blue/green rollback, scaling, and the database security model.
4. IAM and bucket policies checked by tests.
5. CodeBuild, CodeDeploy, and CodePipeline definitions that contain no credentials.

## What was not implemented as a live service

Route 53, ACM, WAF, RDS, Auto Scaling, ECS, ECR, CloudFront, Lambda@Edge, and S3 were not created. S3 Object Lambda was not called. AWS closed that feature to new customers on 7 November 2025. The thumbnail path is a normal function, documented in `docs/task-6/object-lambda-feasibility.md`.

## Order from here

Local validation is the step that can be repeated on Windows:

```powershell
Set-Location "C:\Users\sri charan reddy\Desktop\Elevance-AWS-Internship"
python -m pip install -r requirements.txt
python scripts/run_validation.py
```

Do not run `scripts/terraform-apply.ps1` as part of that check. It exits with an error on purpose.

An AWS apply, when you approve one, is one stack at a time, in this order: Task 6 bucket, Task 2 MySQL, Task 4 service, Task 3 scaling, Task 5 distribution, Task 1 DNS. Each apply needs its own cost note and a destroy step.
