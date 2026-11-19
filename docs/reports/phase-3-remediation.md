# Phase 3 remediation

Date: 19 November 2026, Asia/Calcutta. No AWS API was called. `terraform apply` was not run. `confirm_paid_deployment` remains false. Every plan in this phase added zero resources.

## 1. Executive summary

Phase 3 changed the repository so the Phase 2 defects are either fixed in gated Terraform or stated precisely. Private subnets can reach regional STS and Secrets Manager through interface endpoints, without a NAT path. The pipeline bucket no longer uses the account id `000000000000`. A failed launch hook abandons the instance immediately and still abandons on timeout. The load balancer can send only TCP 3000 to the task security group. The EICAR checker cannot publish an object. Lambda@Edge source is tested and is not associated with CloudFront.

None of this has been created in AWS. Deployment is not the next safe step.

## 2. Issue discovered

Phase 2 found five engineering gaps: no private path from the MySQL subnets to STS, an artifact bucket name that cannot be applied safely, a launch hook that waited out its timeout before abandoning, unrestricted ALB egress, and an EICAR match that treated every other object as publishable. Lambda@Edge was source without an association rule that rejects `$LATEST`.

## 3. Root cause

The Task 2 route table had an S3 gateway only. Interface endpoints and NAT were both absent, so any AWS API call from those subnets had nowhere to go. The artifact name was a literal. The hook's user data exited on failure and relied on the 600 second default. The ALB security group had no egress block, so the provider keeps the AWS default of all outbound traffic. The scanner's empty body fell through to the public prefix. The edge functions were never wired to a version ARN.

One correction to the Phase 2 wording: `generate-db-auth-token` signs locally with instance-metadata credentials. That call does not need a network path to STS. Secrets Manager reads, `sts:GetCallerIdentity`, and any explicit `AssumeRole` do.

## 4. Remediation

**Task 2.** Interface endpoints for `com.amazonaws.ap-south-1.sts` and `com.amazonaws.ap-south-1.secretsmanager`, in both private subnets, with private DNS. The endpoint security group accepts TCP 443 only from the application security group. The STS policy allows `sts:GetCallerIdentity` and not `AssumeRole`. The Secrets Manager policy allows get, describe, put, and version-stage updates on `rds!db-*` and `cloudcart/*`. DNS egress is the VPC resolver at the VPC base address plus two, derived from `10.20.0.0/16`. S3 egress uses the AWS-managed S3 prefix list. `enable_interface_endpoints` defaults to true and is still multiplied by the paid gate, so the count stays zero.

NAT Gateway was rejected because it needs a public subnet, an internet gateway, and a public IPv4 address, and one NAT is a single-AZ failure. A NAT instance has the same internet exposure plus patching. A gateway endpoint does not exist for STS.

**Task 4 bucket.** `data.aws_caller_identity` is read only when `local_validate_credentials` is false. The name is `cloudcart-pipeline-<account-id>-<region>`, or `artifact_bucket_name` when set. Validation rejects the zero account id and an IP-shaped name. The bucket is versioned, AES256 encrypted, public-access blocked, owner-enforced, and denies non-TLS. CodeBuild and CodePipeline both reference that bucket. `prevent_destroy` is set.

**Task 3.** `default_result` remains `ABANDON`. User data sends `ABANDON` on schema mismatch and on error, records one heartbeat, and sends `CONTINUE` only after the check, before starting the ECS agent. The local model terminates the failed instance instead of retrying it. This was not run on EC2.

**ALB.** Egress is one rule: TCP 3000 to `aws_security_group.tasks`. Task ingress is the reverse rule. Task HTTPS remains `0.0.0.0/0` because this stack has no interface endpoints to reference. DNS uses `vpc_cidr`'s resolver when that variable is set, and otherwise stays `0.0.0.0/0` rather than a guessed private range. PostgreSQL 5432 is added only from `database_security_group_id`.

**Scanner.** Verdicts are `infected`, `rejected`, `eicar-negative`, and `not-scanned`. All have `public: false`. Uploads can be presigned only to `incoming/`. Missing bytes are not treated as clean.

**Lambda@Edge.** The image behavior accepts a viewer-request association only for a numeric `us-east-1` version ARN. The query filter preserves CloudFront signed-URL parameters and rejects a broken escape. The WebP handler returns `encoder-not-in-package` instead of inventing a conversion. The signer handler returns 500 if invoked at the edge.

## 5. Files changed

Terraform: `task-2-secure-rds`, `task-3-autoscaling` user data, `task-4-ecs-ecr`, `task-5-cloudfront-edge`, `task-6-s3-storage`. Application: `cloudcart/s3.py`, `cloudcart/scaling.py`, `security/malware/handler.py`, `application/api/server.py`, `application/edge-functions/`. Tests for those paths. The task documents, the architecture note, the threat model, the viva notes, and this report.

## 6. Security impact

The application security group in Task 2 has no route and no rule to the internet. Endpoint policies are narrower than the IAM policies that will also be required. ALB egress no longer defaults to every port. Artifact and image bucket policies still deny non-TLS. The scanner cannot place an object in `public/`. CodeBuild logs are limited to `/aws/codebuild/cloudcart`.

Still open: CodeDeploy actions on the pipeline role use `Resource: "*"`. Task HTTPS egress in the ECS stack is still worldwide on port 443. The STS endpoint does not allow `AssumeRole`. The product-image bucket policy is not attached until a real CloudFront ARN is supplied.

## 7. Cost impact

Nothing was created, so this phase adds no charge.

If an approved apply turns the endpoints on and leaves them: two interface endpoints in two zones, using the planning rate of USD 0.01 per AZ-hour, is USD 0.04 per hour. At ₹93.48 per USD and 18% GST that is about ₹4.40 per hour, ₹26 for six hours, and about ₹3,200 for a 730-hour month, plus USD 0.01 per GB. Confirm the ap-south-1 rate on the VPC pricing page before apply. A NAT Gateway was not added. Its hourly charge and public IPv4 charge would be higher and it was the worse security choice.

`prevent_destroy` on the MySQL instance, the ECR repository, and the artifact bucket stops an accidental destroy. It also blocks teardown until the block is removed. Endpoints, the ALB, the Auto Scaling group, WAF, and CloudFront do not use `prevent_destroy` because those are the resources that must be deletable to stop hourly charges. The MySQL instance also has `deletion_protection`.

## 8. Test evidence

`python3 scripts/run_validation.py` after these edits returned `PASS_WITH_BLOCKERS`. Python: 34 tests, exit 0. Node: 12 tests, exit 0. Terraform fmt, init, validate, and plan succeeded for all six stacks. Plan exit code 0 means no resource changes, because the paid gate is false. That is not an AWS apply. Relative Markdown links: 0 broken. Staged diff secret scan: no access keys or private keys. Docker: BLOCKED, not installed. AWS CLI: BLOCKED, not installed. Port 3000: BLOCKED.

## 9. Remaining limitations

- Endpoints, the bucket, the hook, and the security groups have not been created or observed in AWS.
- IAM database authentication from EC2 has not been performed.
- The five-minute RPO has not been read from `LatestRestorableTime`.
- A repeated hook failure still launches replacements. That loop is visible. It is not solved by admitting bad instances.
- Task 4 cannot open PostgreSQL until `database_security_group_id` is set, and cannot narrow DNS until `vpc_cidr` is set.
- ClamAV is not implemented. Object Lambda is still unavailable to new customers.
- Lambda@Edge is not published. WebP at the edge has no encoder.
- Docker was not available here. The EverShop image was not built.
- GitHub authentication is not available on this machine, so the GitHub branch can stay behind this commit.

## 10. AWS deployment status

No stack is AWS DEPLOYED or AWS VERIFIED. The paid gate is off. Deployment is not safe to start from this change alone.
