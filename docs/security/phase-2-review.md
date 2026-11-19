# Phase 2 security review

Reviewed 19 November 2026 (Asia/Calcutta) against the Terraform and IAM files. No AWS API was called.

## Findings

| Item | What the code does | Risk | Change made |
| --- | --- | --- | --- |
| ECS execution role | Image pull was allowed on `Resource: "*"`. | A task role mistake is not required for this, but the execution role could pull any repository in the account. | Pull actions are limited to `repository/cloudcart`. `ecr:GetAuthorizationToken` stays on `*` because the API rejects a repository ARN. |
| CodeBuild role | Push and scan were allowed on every repository. | A build could write to another repository in the account. | Those actions now use the CloudCart repository ARN. Token retrieval stays on `*`. |
| CodePipeline CodeDeploy actions | `Resource: "*"`. | The pipeline role could start deployments outside CloudCart. | Left unchanged. The CodeDeploy ARN depends on the account and application, and a wrong ARN would fail a future apply. Scope it to the CloudCart application before the first approved apply. |
| ALB security group | Ingress 80 and 443 from `0.0.0.0/0`. No egress block. | Public ingress is required for a public load balancer. With no egress block, the AWS provider keeps the default allow-all egress. | Not changed. Restrict egress to TCP 3000 on the task subnets when the real VPC CIDR is known. |
| Task role | S3, the EverShop secret, and `/cloudcart/*` parameters are prefix-scoped. | Acceptable for the design. The image bucket prefix is `cloudcart-product-images-*`, which matches more than one bucket name. | Not changed. |
| Product-image bucket policy | Denies non-TLS. Allows `s3:GetObject` on `public/*` only for `cloudfront.amazonaws.com` with a source ARN. | The distribution ARN in Task 6 is the placeholder `NOT_DEPLOYED`. | Not changed. Replace it during an approved apply. |
| MySQL security group | Port 3306 from the application security group only. `publicly_accessible` is false. | Matches the private-lab design. The private route table has no NAT or interface endpoint, so an instance there cannot call STS or Secrets Manager. | Not changed. Do not add a NAT Gateway without a separate cost approval. |
| IMDSv2 | The launch template sets `http_tokens = "required"`. | This blocks unauthenticated metadata reads. | Already present. |
| State and secrets | `.env`, `*.tfstate`, and `.terraform/` are gitignored. The secret scan finds no access-key pattern. | Validation still uses the dummy strings `localvalidateonlykey` and `local-validate-only`. | They are not account keys. |
| Pipeline artifact bucket | Name is `cloudcart-pipeline-artifacts-000000000000`. | S3 names are global. This placeholder will fail or collide on apply. | Not changed. Set a unique name before apply. |

No security group opens MySQL to the internet. No stack is applied.
