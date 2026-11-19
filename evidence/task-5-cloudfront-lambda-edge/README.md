# Task 5 — product images on a separate CloudFront distribution.

Status: no AWS evidence. The design note is `docs/task-05-cloudfront-lambda-edge-image-delivery/README.md`. Local checks are not console evidence. The Node tests are not a Lambda@Edge invocation.

## What this change verified

| Class | Result |
| --- | --- |
| Locally verified | Valid image paths, traversal, double encoding, null bytes, method checks, and origin-override rejection. |
| Terraform validated | fmt, init, validate, a zero-change plan, and a rejected apex alias. |
| AWS deployment verified | Nothing. |
| Not yet verified | A published `us-east-1` version, OAC on a real bucket, a cache hit ratio, and log delivery. |

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
