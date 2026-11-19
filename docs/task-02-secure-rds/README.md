# Task 2 — Private database, IAM authentication, rotation, and recovery

Status: **LOCAL / SIMULATED. Not deployed.** The Terraform stack is a separate MySQL 8 security lab: private subnets, Multi-AZ, `publicly_accessible = false`, IAM authentication, `require_secure_transport`, and a Secrets Manager-managed master password. EverShop stays on PostgreSQL. The local rotation, 15-minute token, TLS rejection, and five-minute RPO checks are simulations. `verified_against_rds` is false. No RDS instance exists.

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

**IAM database authentication.** A database user is granted `rds_iam`. An EC2 instance role is allowed `rds-db:connect` on that user. The instance calls `aws rds generate-db-auth-token`. That command signs a token locally with the instance-role credentials from the metadata service. It does not call STS and RDS does not return the token. The token is valid for 15 minutes. The client connects with the database user name, the token in the password field, and TLS. The instance profile supplies the credentials. No access key is placed on the instance. The local function in `cloudcart/db.py` only imitates the token shape.

**Secrets Manager rotation.** A second database user has a normal password. The password is stored as a secret. On a schedule, the rotation function changes the password in the database and stores the new version. The application reads the current password with `secretsmanager:GetSecretValue`, using its task role. IAM here decides who may read the secret. The database still checks a password. A stolen secret remains useful until the next rotation. An IAM token expires in 15 minutes.

## Recovery point and recovery time

Automated backups plus transaction logs give point-in-time recovery inside the retention window. RDS uploads those logs about every five minutes, so the latest restorable time is normally within about five minutes of now. The evidence for a five-minute RPO is that timestamp compared with the clock.

Restoring builds a new database instance. That work often takes much longer than five minutes. The brief does not set a five-minute recovery time. The original instance is left in place by a restore. The new instance is deleted after the screenshot, because it is billed separately.

## Network and IAM

The implemented lab is MySQL in this repository's Task 2 stack. The PostgreSQL notes above are the EverShop store, not this stack.

- Two private subnets, `10.20.10.0/24` and `10.20.11.0/24`, with a route table that has an S3 gateway endpoint and no internet route.
- `publicly_accessible` is false. The database security group allows TCP 3306 from the application security group only. The parameter `require_secure_transport` is 1.
- Phase 3 adds interface endpoints for `com.amazonaws.ap-south-1.sts` and `com.amazonaws.ap-south-1.secretsmanager` when `enable_interface_endpoints` and the paid gate are both true. Private DNS is on. The STS endpoint policy allows only `sts:GetCallerIdentity`. Clients must use the regional STS name. The global name `sts.amazonaws.com` is not served by this endpoint.
- NAT Gateway and a NAT instance were rejected. Both need an internet path. Interface endpoints do not.
- The endpoints are not created. `terraform plan` still adds nothing. Connectivity has not been verified against AWS.
- Planning cost, to be checked on the VPC pricing page before any apply: about USD 0.01 per endpoint ENI-hour. Two endpoints in two zones is about USD 0.04 per hour, about ₹4.40 per hour with GST at ₹93.48 per USD, and about ₹3,200 per month if left running. Data processing is extra.

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

No VPC, subnet, instance, secret, or restore exists in AWS. The five-minute figure is the RDS log-upload interval used by the calculator. It is not a measured `LatestRestorableTime`. Label: SIMULATED, and BLOCKED for REAL_AWS.
