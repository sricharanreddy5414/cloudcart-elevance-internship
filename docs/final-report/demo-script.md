# Demonstration script

Target length: about four minutes. No recording has been made. Do not record secrets, the root account, or a screen that shows a password.

## 0:00 Architecture

"CloudCart is EverShop with six infrastructure tasks around one store. The store uses PostgreSQL. Task 2's MySQL design is a separate security lab, because EverShop does not run on MySQL. Nothing in this demo is an AWS account unless I am showing a console I actually created."

Show `docs/ARCHITECTURE.md`.

## 0:40 Store

If the Windows store is running, open `http://localhost:3000` and the admin. Say that the Compose file pins the image digest and does not publish the database port.

If it is not running, say so. Do not pretend it is.

## 1:20 Containers and tests

Show the Dockerfile digest and then run:

```powershell
python scripts/run_validation.py
```

Read the status line. Point at a passing presign test, the quarantine test, and the edge tests. Say which checks are blocked.

## 2:10 Security

Show the bucket policy deny for insecure transport, the split between the ECS task role and the execution role, and the two MySQL users. Say that IAM authentication was not performed against RDS.

## 2:50 Failure model

Show the chaos test: one zone can fail and the other serves; both zones failing does not. Show the blue/green test: unhealthy green rolls back to blue.

## 3:30 Limits

"Terraform plan adds no resources while the approval flag is false. Route 53, ACM, WAF, RDS, ECS, CloudFront, and S3 have not been created. Object Lambda is closed to new customers. The five-minute RPO has not been measured on RDS. I will not submit until the evidence matches these words."

Stop. Keep the file under 100 MB.
