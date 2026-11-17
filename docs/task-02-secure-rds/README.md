# Task 2 — Private database, IAM authentication, rotation, and recovery

Status: **Not started.** No database has been created in AWS. The local database is PostgreSQL 16 in Docker, on the Windows machine, and it stays there.

## Objective

Run the EverShop database in private subnets, with Multi-AZ, no public address, encrypted connections, two different authentication mechanisms, and a demonstrated five-minute recovery point.

## Requirements

1. Database in private subnets.
2. Multi-AZ.
3. Public accessibility disabled.
4. IAM database authentication.
5. TLS-only connections.
6. Secrets Manager automatic rotation.
7. An EC2 instance authenticating with a temporary IAM token.
8. Point-in-time recovery.
9. Evidence for the requested five-minute RPO.

## Engine conflict

The brief names MySQL. EverShop supports PostgreSQL only. Decision D-001 proposes RDS for PostgreSQL, with every control above, and asks the mentor whether a separate unused MySQL instance is also required. Neither database will be created until that is answered and the cost is approved.

RDS for PostgreSQL supports IAM database authentication, Secrets Manager rotation, Multi-AZ, and `rds.force_ssl`.

## Two mechanisms

These are different logins. Demonstrating one does not demonstrate the other.

**IAM database authentication.** A database user is granted `rds_iam`. An EC2 instance role is allowed `rds-db:connect` on that user. The instance calls `aws rds generate-db-auth-token`. RDS returns a signed token that is valid for 15 minutes. The client connects with the database user name, the token in the password field, and TLS. PostgreSQL checks the token with IAM. On PostgreSQL, IAM authentication takes over for a user that has `rds_iam`, so that same user is not the password user. The instance uses the role's temporary credentials from the metadata service. No access key is placed on the instance.

**Secrets Manager rotation.** A second database user has a normal password. The password is stored as a secret. On a schedule, the rotation function changes the password in the database and stores the new version. The application reads the current password with `secretsmanager:GetSecretValue`, using its task role. IAM here decides who may read the secret. The database still checks a password. A stolen secret remains useful until the next rotation. An IAM token expires in 15 minutes.

## Recovery point and recovery time

Automated backups plus transaction logs give point-in-time recovery inside the retention window. RDS uploads those logs about every five minutes, so the latest restorable time is normally within about five minutes of now. The evidence for a five-minute RPO is that timestamp compared with the clock.

Restoring builds a new database instance. That work often takes much longer than five minutes. The brief does not set a five-minute recovery time. The original instance is left in place by a restore. The new instance is deleted after the screenshot, because it is billed separately.

## Network and IAM

- DB subnet group: at least two private subnets in two Availability Zones.
- `PubliclyAccessible` is false. No internet gateway route is required for the subnets to be private; the route tables will be checked anyway.
- The database security group allows TCP 5432 from the application security group only.
- A custom parameter group sets `rds.force_ssl=1` if the default is not already on. PostgreSQL 15 and later default it to on.
- Clients use `sslmode=verify-full` and the Amazon RDS CA bundle.

## Evidence to collect later

- VPC, private subnets, and route tables.
- RDS settings: engine, Multi-AZ, public access, backup retention, IAM auth, parameter group.
- Security group rules.
- A successful connection with an IAM token from EC2, and a rejected non-TLS connection.
- A rotation that produces a new secret version and still allows a login.
- `LatestRestorableTime` within about five minutes of the check. If a restore is approved, the new instance's endpoint and the time the restore took, labeled as recovery time.

## Cost

Multi-AZ bills two instances and is outside the classic free-tier database allowance. A restore bills another instance until it is deleted. Secrets Manager bills per secret per month. Approval is required before either is created. Single-AZ is cheaper and does not meet the Multi-AZ requirement; if that is all that gets approved, the report will say so.

## Not done

No VPC, no subnet, no instance, no secret, no restore.
