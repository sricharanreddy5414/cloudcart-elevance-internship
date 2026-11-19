# Terraform validation

Label: LOCAL. `terraform plan` was read-only. `terraform apply` was not run. No resource was created.

The same six results were reproduced on 19 November 2026 at 10:50 PM IST with Terraform 1.9.8. Each plan exit code was 0.

Tool: Terraform v1.9.8 on linux_amd64. The Windows machine was reported as Terraform 1.17.1; that binary was not used for this run. Provider: `hashicorp/aws` 5.74.0, already present in each stack's `.terraform` directory. Backend: disabled (`-backend=false`).

Each stack uses dummy validation credentials (`localvalidateonlykey` / `local-validate-only`) and `skip_credentials_validation`. Those values are not AWS keys. `confirm_paid_deployment` stayed false, so `module.guard.resource_count` is 0.

| Stack | fmt -check | init | validate | plan exit | Plan result |
| --- | --- | --- | --- | --- | --- |
| task-1-route53-acm-waf | 0 | 0 | 0 | 0 | No changes |
| task-2-secure-rds | 0 | 0 | 0 | 0 | No changes |
| task-3-autoscaling | 0 | 0 | 0 | 0 | No changes |
| task-4-ecs-ecr | 0 | 0 | 0 | 0 | No changes |
| task-5-cloudfront-edge | 0 | 0 | 0 | 0 | No changes |
| task-6-s3-storage | 0 | 0 | 0 | 0 | No changes |

Exit code 0 from `terraform plan -detailed-exitcode` means the plan proposed no changes. The new CodePipeline resources are included in task 4 and still add nothing, because their count is zero.

Command stdout and stderr are in `evidence/test-results/validation-report.json`.
