# CloudCart

EverShop store for the Elevance Skills Cloud Technology internship. The internship asks for six AWS capabilities around one store: DNS and TLS, a private database, automatic capacity, immutable container delivery, a CloudFront edge, and private product images. This repository holds the design and the local tests. None of the six has been deployed. A local test is not AWS evidence.

GitHub `main` was still `0535dcf` on 19 November 2026 (Asia/Calcutta). The later review commits are local until `git push github main` succeeds. Do not force-push.

| | |
| --- | --- |
| Repository | https://github.com/sricharanreddy5414/cloudcart-elevance-internship |
| Deadline | 17 December 2026 |
| Store database | PostgreSQL. Do not point EverShop at MySQL. |
| Task 2 | Separate MySQL security lab. Not deployed. |
| Budget target | ₹0. Paid resources stay gated until an explicit approval. |
| Status | CODE READY and LOCALLY VALIDATED where noted. No task is AWS DEPLOYED. |

An evaluator can read [the matrix](docs/reports/six-task-matrix.md) and [the evidence index](evidence/README.md). The cost of a real deployment is in [the zero-cost review](docs/reports/zero-cost-strategy.md).

CloudCart is the integrated e-commerce project. EverShop is the store application. The six tasks cover DNS and edge security, a private database, auto scaling, immutable container delivery, CloudFront, and private product-image storage.

The public project repository is [sricharanreddy5414/cloudcart-elevance-internship](https://github.com/sricharanreddy5414/cloudcart-elevance-internship).

The running store, when it is the original installation, stays on the Windows machine:

- Original store folder: `C:\Users\sri charan reddy\Desktop\Elevance-AWS-Internship`
- Export folder named for this repository: `C:\Users\sri charan reddy\Desktop\CloudCart-export`
- Store: `http://localhost:3000`
- Admin: `http://localhost:3000/admin`
- Database: PostgreSQL 16, Docker volume `postgres-data`

Do not copy this repository over the original store folder, and do not delete `postgres-data`. EverShop uses PostgreSQL. The MySQL design is a separate security lab.

## Six tasks

| Task | What it asks for | In this repository | Deployed |
| --- | --- | --- | --- |
| 1 | Domain, Route 53, ACM, WAF, failover | [Terraform and notes](docs/task-01-route53-acm-waf/README.md) | No |
| 2 | Private Multi-AZ MySQL, IAM auth, rotation, recovery | [Separate from the store database](docs/task-02-secure-rds/README.md) | No |
| 3 | Mixed Spot and On-Demand, scaling, failure tests | [Model, not EC2](docs/task-03-autoscaling/README.md) | No |
| 4 | EverShop on ECS, ECR, CodePipeline, blue/green | [Image file, not a built image](docs/task-04-ecs-ecr-cicd/README.md) | No |
| 5 | Private S3 origin, CloudFront, Lambda@Edge | [Source, not a published function](docs/task-05-cloudfront-lambda-edge-image-delivery/README.md) | No |
| 6 | Private images, lifecycle, inventory, scanning | [Quarantine pipeline, not a live scan](docs/task-06-secure-image-storage-pipeline/README.md) | No |

The store database is PostgreSQL. Task 2 does not replace it. Architecture: [docs/architecture/integrated-architecture.md](docs/architecture/integrated-architecture.md). Order, if a deployment is ever approved: [docs/reports/deployment-dependency-map.md](docs/reports/deployment-dependency-map.md).

## Current truth

Reviewed on 19 November 2026 (Asia/Calcutta). The 17 November plan results are historical until the Phase 1 re-run recorded in `evidence/test-results/`.

| Item | State |
| --- | --- |
| EverShop on Windows | Not reached from this environment. Port 3000 was closed here. |
| Local implementation and tests | Python and Node tests passed. Six Terraform stacks validated and planned no changes. |
| Docker in the validation environment | Not installed. The image was not built here. |
| AWS resources for CloudCart | None created. |
| AWS spend approved | No. The target is ₹0. A month of the required stack is about ₹12,000 with GST. See [the zero-cost review](docs/reports/zero-cost-strategy.md). |
| Tasks 1–6 | Designed, implemented as local code, and not deployed. See [the matrix](docs/reports/six-task-matrix.md). |
| Final submission | Not ready. Deadline 17 December 2026. |

A local Docker test, a Terraform plan, or a diagram is not an AWS deployment. Each later result will be marked as one of:

- **A.** Implemented and tested locally.
- **B.** Simulated AWS behavior.
- **C.** An AWS resource that was actually created.
- **D.** Live AWS evidence that was checked.

## How we work

One step at a time. Each step has an objective, the exact PowerShell command, the expected output, and a pause for the real result. Nothing that can create a charge is created until the cost of that resource is explained and explicitly approved.

The active step is [docs/planning/next-step.md](docs/planning/next-step.md).

## How to run the checks

```powershell
Set-Location "C:\Users\sri charan reddy\Desktop\CloudCart-export"
python -m pip install -r requirements.txt
python scripts/run_validation.py
```

Leave the existing store running. Do not run `docker compose down -v`, and do not delete the `postgres-data` volume. Do not apply Terraform. Progress is in [docs/PROJECT_PROGRESS.md](docs/PROJECT_PROGRESS.md).

## Map

- [Architecture](docs/architecture/integrated-architecture.md)
- [Cost approval gate](docs/architecture/cost-approval-gate.md)
- [AWS account baseline](docs/security/account-baseline.md)
- [30-day plan](docs/planning/30-day-plan.md)
- [Task tracker](docs/planning/task-tracker.md)
- [Decision log](docs/planning/decision-log.md)
- [Questions for the internship mentor](docs/mentor/questions-for-mentor.md)
- [Evidence rules](docs/testing/evidence-rules.md)
- [Six-task matrix](docs/reports/six-task-matrix.md)
- [Security design](docs/security/threat-model.md)
- [Service availability](docs/limitations/aws-service-availability.md)
- [Known blockers](docs/limitations/known-blockers.md)
- [Blocker register](docs/reports/blocker-register.md)
- [Deployment order](docs/reports/deployment-dependency-map.md)
- [Test categories](docs/testing/test-categories.md)
- [Container review](docs/security/container-review.md)
- [Local run notes](docs/deployment/local.md)
- [Evidence index](evidence/README.md)
- [Zero-cost review](docs/reports/zero-cost-strategy.md)
- [Viva preparation](docs/final-report/viva-preparation.md)
- [Phase 2 security review](docs/security/phase-2-review.md)
- [Phase 3 remediation](docs/reports/phase-3-remediation.md)
- [Phase 2 cost by resource](docs/reports/phase-2-cost-by-resource.md)
- [Submission checklist](docs/final-report/submission-checklist.md)

## What an evaluator should trust

Local tests and Terraform plans are in `evidence/test-results/`. They do not show a running AWS service. The task evidence folders are empty templates. There is no live URL.

Security notes are in [docs/security/phase-2-review.md](docs/security/phase-2-review.md). Paid resources stay off until a named approval. Cleanup has not been required because nothing was created.

Learning recorded here: CloudFront certificates are regional, IAM database tokens and password rotation are different controls, and a backup retention period is not a measured recovery point.

Known limits: GitHub is behind the local commits, no domain, no Docker in the last validation environment, Lambda@Edge is not associated, Object Lambda is unavailable to new customers, and the malware check is EICAR-only. The open list is [the blocker register](docs/reports/blocker-register.md).
