# AWS identity check, still required before any apply

Local implementation and tests now exist. Read `docs/PROJECT_PROGRESS.md`. This identity check is still the gate before any AWS create.

# Current step — identify the AWS principal

Status: waiting for you to run this on Windows.  
Date opened: 17 November 2026 (Asia/Calcutta).

## Objective

Find out which AWS identity the CLI will use, before any resource is created.

## Why this is the first step

CloudCart cannot be deployed safely until we know the caller. The CLI has previously authenticated as the AWS account root user. Root can create, modify, and delete every resource, and a root access key cannot be limited with an identity policy. Application deployment and infrastructure provisioning will use a non-root identity. This command only reads the caller. It does not create a resource and it does not have a charge.

## What this step does not do

Do not create users, roles, keys, buckets, VPCs, or budgets yet. Do not run `terraform apply`. Do not stop Docker. Do not delete a volume. Do not paste access keys, secret keys, session tokens, or passwords into chat.

## Commands

Use Windows PowerShell 5.1. These use the default AWS profile.

```powershell
aws sts get-caller-identity --query Arn --output text
aws configure get region
```

## Expected output

The first command prints one line, an Amazon Resource Name:

- `arn:aws:iam::123456789012:root` means the CLI is root. Stop. Create nothing.
- `arn:aws:iam::123456789012:user/some-name` means a long-lived IAM user.
- `arn:aws:sts::123456789012:assumed-role/some-role/some-session` means temporary role credentials. This is the preferred kind of identity.

The second command prints the configured region, or nothing if no default region is set. The workload region we intend to use later is `ap-south-1` (Mumbai). CloudFront certificates and Lambda@Edge have to be created in `us-east-1` later. Do not change the region in this step.

## What to send back

Send the two lines. You may mask the 12-digit account id. Keep the part that shows `root`, `user/...`, or `assumed-role/...`, and keep the region.

If a command fails, send the error text only. Typical messages are `Unable to locate credentials`, `ExpiredToken`, or `InvalidClientTokenId`. Do not reinstall the AWS CLI because of one of those messages.

## Same sitting, with nothing to paste back

The EverShop administrator password was previously visible in terminal output. Change it in the admin UI at `http://localhost:3000/admin` to a new password that has never been typed in a terminal. Do not send either password here.

Then close the terminal window that showed the password. Open this file in Notepad and delete only the lines that contain the password:

```text
%APPDATA%\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt
```

Do not run `Get-Content` on that file and paste the result.

When you can, send the two questions in [../mentor/questions-for-mentor.md](../mentor/questions-for-mentor.md) to the internship mentor. We can inspect Docker on the next session without that reply. We cannot treat a local simulation as an evaluable AWS deployment without that reply.

## After your result

I will read the ARN and the region, then give the single following step. If the ARN is root, that step is a console-only IAM administrator with MFA, and root access keys are removed. If the ARN is already a user or role, that step is to confirm MFA and the attached permissions before any create call.
