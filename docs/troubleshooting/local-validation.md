# Troubleshooting

## `python` is not recognized

Install Python 3.12 for Windows, or run `py -3 scripts/run_validation.py`.

## Docker is missing

The validation report marks Docker as BLOCKED. That is a missing tool, not a failed container. Do not reinstall Docker on a machine where EverShop is already running unless you have decided to. The existing store does not need a reinstall for the unit tests.

## localhost:3000 refused the connection

The store is not running in that environment. On the Windows machine, check it with `docker compose ps` in the existing project directory. Do not run `docker compose down -v`.

## Terraform wants to create resources

Stop. `confirm_paid_deployment` should be false, and the plan should say no changes. If it proposes creates, do not apply. Inspect the variable file that turned the guard on.

## A test mentions a five-minute RPO

The calculator compares two timestamps you supply. It does not restore RDS. `verified_against_rds` stays false until a real `LatestRestorableTime` is read from an instance you created.

## Signed URL or presign tests

They generate signatures on the machine. A passing test does not mean CloudFront or S3 accepted the URL.
