# Task 4 — EverShop on ECS, ECR, the ALB, and the pipeline.

Status: no AWS evidence. The design note is `docs/task-04-ecs-ecr-cicd/README.md`. Local checks are not console evidence. Docker was not available, so there is no image build log and no runtime log.

## What this change verified

| Class | Result |
| --- | --- |
| Locally verified | Digest pin, no `:latest`, PostgreSQL port 5432, approval before deploy, managed scaling left disabled, and rollback image selection. |
| Terraform validated | fmt, init, validate, a zero-change plan, and a rejected `:latest` image URI. |
| Docker validated | Not validated. |
| AWS deployment verified | Nothing. |
| Not yet verified | ECR, a pushed digest, ECS tasks, ALB target health, a CodeDeploy shift, and a live rollback. |

The folders `screenshots/`, `logs/`, `test-results/`, and `configurations/` are empty templates. Nothing in them is an AWS console capture.

Local test output stays in `evidence/test-results/` and is labeled LOCAL.

## Evidence checklist

All boxes stay open until a real AWS run fills them. Do not check a box for a local test.

- [ ] Requirement reference
- [ ] Architecture
- [ ] AWS resource identification
- [ ] Deployment timestamp
- [ ] Region
- [ ] Screenshot evidence
- [ ] Configuration evidence
- [ ] Test commands
- [ ] Actual test output
- [ ] Security verification
- [ ] Cost tracking
- [ ] Cleanup record
- [ ] Post-cleanup verification
