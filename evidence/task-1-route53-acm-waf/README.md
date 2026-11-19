# Task 1 — Route 53, ACM, HTTPS, HSTS, failover, and WAF.

Status: no AWS evidence. Local Terraform and unit checks are recorded under `evidence/test-results/` and are not console evidence. The design note is `docs/task-01-route53-acm-waf/README.md`.

The folders `screenshots/`, `logs/`, `test-results/`, and `configurations/` are empty templates. Nothing in them is an AWS console capture.

Local test output stays in `evidence/test-results/` and is labeled LOCAL.

## What this change verified

| Class | Result |
| --- | --- |
| Locally verified | Contract test reads the Terraform. HSTS and HTTPS redirect helpers remain unit-tested. No packet was sent. |
| Terraform validated | `fmt`, `init -backend=false`, `validate`, and `plan` for Task 1 and Task 4 exited 0. The plan reported no changes because `confirm_paid_deployment` is false. |
| AWS deployment verified | Nothing. No zone, certificate, distribution, web ACL, or load balancer was created. |
| Not yet verified | Delegation, issued certificates, TLS handshake, HSTS on the wire, WAF samples, origin failover, prefix-list quota, and cost. |

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
