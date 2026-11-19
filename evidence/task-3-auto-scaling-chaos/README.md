# Task 3 — mixed Auto Scaling, lifecycle hooks, and failure tests.

Status: no AWS evidence. The design note is `docs/task-03-autoscaling/README.md`. Local checks are not console evidence.

## What this change verified

| Class | Result |
| --- | --- |
| Locally verified | The chaos model covers abandon, timeout, Spot interruption, scale-in, and an unready host. |
| Terraform validated | fmt, init, validate, a zero-change plan, and a rejected desired capacity of 9. |
| AWS deployment verified | Nothing. |
| Not yet verified | A live group, a Spot notice, a scale event, and a zone removal under load. |

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
