# Phase 2 security review

Reviewed 19 November 2026 (Asia/Calcutta) against the Terraform and IAM files. No AWS API was called.

## Findings

| Item | What the code does | Risk | Change made |
| --- | --- | --- | --- |
| ECS execution role | Image pull was allowed on `Resource: "*"`. | A task role mistake is not required for this, but the execution role could pull any repository in the account. | Pull actions are limited to `repository/cloudcart`. `ecr:GetAuthorizationToken` stays on `*` because the API rejects a repository ARN. |
| CodeBuild role | Push and scan were allowed on every repository. | A build could write to another repository in the account. | Those actions now use the CloudCart repository ARN. Token retrieval stays on `*`. |
| CodePipeline CodeDeploy actions | `Resource: "*"`. | The pipeline role could start deployments outside CloudCart. | Left unchanged. The CodeDeploy ARN depends on the account and application, and a wrong ARN would fail a future apply. Scope it to the CloudCart application before the first approved apply. |
| ALB security group | Ingress 80 and 443 from `0.0.0.0/0`. No egress block. | Public ingress is required for a public load balancer. With no egress block, the AWS provider keeps the default allow-all egress. | Phase 3 restricts ALB egress to TCP 3000 on the task security group. See `docs/reports/phase-3-remediation.md`. |
| Task role | S3, the EverShop secret, and `/cloudcart/*` parameters are prefix-scoped. | Acceptable for the design. The image bucket prefix is `cloudcart-product-images-*`, which matches more than one bucket name. | Not changed. |
| Product-image bucket policy | Denies non-TLS. Allows `s3:GetObject` on `public/*` only for `cloudfront.amazonaws.com` with a source ARN. | The distribution ARN in Task 6 was the placeholder `NOT_DEPLOYED`. | Phase 3 rejects a paid apply until `cloudfront_distribution_arn` is a real distribution ARN. |
| MySQL security group | Port 3306 from the application security group only. `publicly_accessible` is false. | The private route table had no path to STS or Secrets Manager. | Phase 3 adds gated interface endpoints. They have not been created. |
| IMDSv2 | The launch template sets `http_tokens = "required"`. | This blocks unauthenticated metadata reads. | Already present. |
| State and secrets | `.env`, `*.tfstate`, and `.terraform/` are gitignored. The secret scan finds no access-key pattern. | Validation still uses the dummy strings `localvalidateonlykey` and `local-validate-only`. | They are not account keys. |
| Pipeline artifact bucket | Name was `cloudcart-pipeline-artifacts-000000000000`. | S3 names are global. That placeholder would fail or collide on apply. | Phase 3 removed it. The name comes from the account id and region, or from `artifact_bucket_name`. |

No security group opens MySQL to the internet. No stack is applied.
