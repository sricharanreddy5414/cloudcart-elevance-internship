# CloudCart

CloudCart is the integrated e-commerce project for the Elevance Skills Cloud Technology internship. EverShop is the store application. Six AWS tasks share one architecture: DNS and edge security, a private database, auto scaling, immutable container delivery, CloudFront, and private product-image storage.

The public project repository is [sricharanreddy5414/cloudcart-elevance-internship](https://github.com/sricharanreddy5414/cloudcart-elevance-internship).

The running store, when it is the original installation, stays on the Windows machine:

- Original store folder: `C:\Users\sri charan reddy\Desktop\Elevance-AWS-Internship`
- Export folder named for this repository: `C:\Users\sri charan reddy\Desktop\CloudCart-export`
- Store: `http://localhost:3000`
- Admin: `http://localhost:3000/admin`
- Database: PostgreSQL 16, Docker volume `postgres-data`

Do not copy this repository over the original store folder, and do not delete `postgres-data`. EverShop uses PostgreSQL. The MySQL design is a separate security lab.

## Current truth

Reviewed on 17 November 2026 (Asia/Calcutta), after a validation run on Linux.

| Item | State |
| --- | --- |
| EverShop on Windows | Not reached from this environment. Port 3000 was closed here. |
| Local implementation and tests | Python and Node tests passed. Six Terraform stacks validated and planned no changes. |
| Docker in the validation environment | Not installed. The image was not built here. |
| AWS resources for CloudCart | None created. |
| AWS spend approved | No. The ₹500 target does not cover a month of the required stack. See [the cost plan](docs/reports/phase-0-cost-and-deployment-plan.md). |
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
- [Evidence index](evidence/README.md)
- [Submission checklist](docs/final-report/submission-checklist.md)
