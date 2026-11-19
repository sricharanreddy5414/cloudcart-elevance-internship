# Task 6 — quarantine, scan, and the public product prefix.

Status: no AWS evidence. The design note is `docs/task-06-secure-image-storage-pipeline/README.md`. A local presigned POST is not an S3 upload. The EICAR match is not ClamAV.

## What this change verified

| Class | Result |
| --- | --- |
| Locally verified | Authorized quarantine posts, JPEG/PNG/WebP checks, EICAR rejection, fail-closed worker, and the Task 5 destination key. |
| Simulated | A fresh signature engine can return CLEAN. That engine is not deployed. |
| Terraform validated | fmt, init, validate, a zero-change plan, and a rejected zero-account distribution ARN. |
| AWS deployment verified | Nothing. |
| Not yet verified | A bucket, a queue delivery, a Lambda invocation, inventory output, and a CloudFront read. |

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
