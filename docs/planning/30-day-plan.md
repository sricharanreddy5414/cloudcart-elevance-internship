# 30-day plan

Start: 17 November 2026. Submission deadline: 17 December 2026.  
Pace: 3–4 focused hours on the days you work. Times below are sequencing, not a promise that a cloud service will be finished on that date.

The plan has two tracks. Track A is always available and costs ₹0. Track B creates AWS resources and starts only after the identity check, a budget alarm, and an explicit approval for the resources of that day.

## Week 1 — 17 to 23 November — freeze the rules and the app

Track A:

1. Identify the CLI principal. If it is root, stop.
2. Rotate the EverShop administrator password and remove it from shell history.
3. Send the mentor questions.
4. Read the existing Compose file. One command, no edits.
5. Confirm the store is healthy with `docker compose ps`.
6. Configure the store and add a small real catalog in the admin UI, so later screenshots show a store rather than an empty installer.
7. Read EverShop's media storage settings and decide how the production image will point at S3.

Track B: none this week, unless the identity is already a non-root role and you choose to create only a budget alarm.

Exit: a known principal, a rotated admin password, a written spend ceiling from you, and a store with products.

## Week 2 — 24 to 30 November — database and images on paper, then the cheapest live proof

Track A:

- Write the VPC, security group, and RDS PostgreSQL template. Run `terraform validate` or a CloudFormation lint. Do not apply.
- Write the S3 bucket policy, encryption, ownership, and lifecycle documents.
- Write the difference between the IAM database user and the rotating password user, with the exact SQL and CLI each will use later.
- Unit-test the presigned-URL sample against a local stand-in only if we label it simulated.

Track B, only if approved, in this order, deleted the same day unless you accept the monthly cost:

1. Billing alarm at your ceiling.
2. One private S3 bucket and a presigned upload/download test. This is the cheapest live evidence and the store needs shared media before scaling.
3. Malware-scan function test with one harmless file and one EICAR test file.

Exit: Task 6 is either live-verified for the bucket controls, or fully specified and blocked on approval. Task 2 is specified and not deployed.

## Week 3 — 1 to 7 December — database, registry, and the service

Track A:

- Production Dockerfile beside the existing Compose file, without replacing it.
- Task definition, CodeBuild `buildspec.yml`, and CodeDeploy blue/green document.
- Local image build and a Compose test that the new image still opens the admin login.

Track B, one afternoon, with a destroy checklist printed first:

- RDS for PostgreSQL, private, TLS required. Multi-AZ only if you approve that higher hourly rate. If you approve single-AZ only, the report will say Multi-AZ was not deployed and why.
- IAM token test from an EC2 role, and a rotation test of the other user.
- Point-in-time recovery evidence from `LatestRestorableTime`. A restore, if approved, is deleted the same day.
- ECR, ECS on EC2, and the ALB. Blue/green is demonstrated only if the traffic shift and the rollback both happen.

Exit: either live evidence for Tasks 2 and 4, or an honest blocker and local artifacts.

## Week 4 — 8 to 14 December — scaling, edge, and DNS

Track A, in parallel with whatever Track B time remains:

- Auto Scaling policy JSON, lifecycle-hook script, and the chaos-test procedure.
- Lambda@Edge source and local tests for query filtering and the 1 MB WebP limit.
- WAF web ACL JSON for both scopes.
- Architecture diagrams updated to match what was actually built.

Track B, if the origin from week 3 exists and you approve the extra charges:

- Mixed-instance group, one controlled termination, one Availability Zone removal, with timestamps.
- CloudFront, OAC, signed URLs, and cache statistics.
- Route 53, both certificates, HSTS, both WAF associations, and a failover test.

Exit: every task is either verified, or blocked with a named reason. Nothing is marked verified from a simulation.

## 15 to 17 December — submission only if you say so

- Evidence index. Every screenshot is real and contains no secret.
- Final report: what was deployed, what was simulated, what it cost, what failed.
- Demo of 2–5 minutes, at most 100 MB, showing only behavior that the evidence supports.
- Walk the submission checklist. You confirm in writing. Then, and only then, the portal is used.

The portal allows one submission and no replacement. A public link has to open without a login.

## If a week slips

The order of sacrifice is: interview extras first, then live chaos and live failover, then live blue/green. The database security story, the private bucket, and an honest report stay. A missing live test is written as blocked. It is not replaced with a claim that local Docker was the AWS service.
