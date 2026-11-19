# Task 2 — private Multi-AZ MySQL, IAM authentication, TLS, rotation, and recovery.

Status: no AWS evidence. Local Terraform and unit checks are recorded under `evidence/test-results/` and are not console evidence. The design note is `docs/task-02-secure-rds/README.md`.

## What this change verified

| Class | Result |
| --- | --- |
| Locally verified | Contract tests read the Terraform. Rotation, token lifetime, and the RPO calculator are unit tests. `verified_against_rds` stays false. |
| Terraform validated | fmt, init, validate, and a zero-change plan. A plan with `backup_retention_days=0` is rejected. |
| AWS deployment verified | Nothing. |
| Not yet verified | The instance, the IAM login, rotation, `LatestRestorableTime`, and a restore. |

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
