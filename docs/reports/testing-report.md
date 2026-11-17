# Testing report

Label: LOCAL, except the two blocked checks. No test called AWS.

Command:

```text
python3 scripts/run_validation.py
```

The runner prints `RUN` before each command and `EXIT` with the code after it. The run at 2026-11-17T13:30:28Z (7:00 PM IST) is recorded in `evidence/test-results/validation-report.md`. Overall status: PASS_WITH_BLOCKERS.

| Check | Result | Kind |
| --- | --- | --- |
| Python unittest (`tests/**/test_*.py`) | PASS, 31 tests, exit 0 | LOCAL |
| `node --test application/edge-functions/edge.test.js` | PASS, 8 tests, exit 0 | LOCAL |
| Terraform fmt, init, validate, plan for six stacks | PASS, plan exit 0 | LOCAL |
| `docker ps` | BLOCKED. `docker` is not on PATH | BLOCKED |
| `http://127.0.0.1:3000/` | BLOCKED. Connection refused | BLOCKED |

What the passing tests cover:

- Presigned URL host is local and the URL expires.
- EICAR content is quarantined. A clean object is not.
- Pillow writes a WebP thumbnail.
- Query allow-list, cache headers, the 1 MB WebP guard, and signed-URL expiry.
- IAM token lifetime, password rotation, TLS rejection, and the RPO calculator with `verified_against_rds` false.
- Mixed capacity, lifecycle warm-up, and zone loss inside the scaling model.
- Blue/green shift and rollback inside `cloudcart/deploy.py`.
- Terraform text contracts for all six stacks, including the CodePipeline role principals.

What was not tested:

- A running EverShop login, catalog, or upload.
- A Docker image build.
- A real RDS restore, EC2 termination, CloudFront cache statistic, or S3 inventory report.

Python on this machine was 3.12.3. Node was v22.23.4. The Windows notes say Python 3.11 and Node.js 24. Those versions were not re-run here.
