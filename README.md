# CloudCart

CloudCart is the integrated e-commerce project for the Elevance Skills Cloud Technology internship. EverShop is the store application. Six AWS tasks share one architecture: DNS and edge security, a private database, auto scaling, immutable container delivery, CloudFront, and private product-image storage.

The running store stays on the Windows machine where it was already installed:

- Project folder: `C:\Users\sri charan reddy\Desktop\Elevance-AWS-Internship`
- Store: `http://localhost:3000`
- Admin: `http://localhost:3000/admin`
- Database: PostgreSQL 16, Docker volume `postgres-data`

This repository is the project notebook: architecture, decisions, task status, and later the infrastructure code and evidence index. It does not replace that Windows folder, and it does not start a second copy of EverShop.

## Current truth

Reviewed on 17 November 2026 (Asia/Calcutta).

| Item | State |
| --- | --- |
| EverShop on Windows | Reported running. This environment could not reach it. |
| Local implementation and tests | Present. Run `python scripts/run_validation.py`. |
| AWS resources for CloudCart | None created. Terraform plan adds nothing until you approve a stack. |
| AWS spend approved | No. |
| Tasks 1–6 | Tested locally. Not deployed and not verified in AWS. |
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
Set-Location "C:\Users\sri charan reddy\Desktop\Elevance-AWS-Internship"
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
- [Submission checklist](docs/final-report/submission-checklist.md)
