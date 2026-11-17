# AWS account baseline

No AWS API call has been made from this project. The rules below are in force before the first create call.

## Root

The AWS root user owns the account. It is the identity that can close the account, change billing, and bypass IAM policies attached to other users. A root access key on a laptop is a full-account credential.

CloudCart deployment will not use root. The allowed uses of root, done in the console with MFA, are the account tasks AWS still requires root for: enabling MFA on root, deleting root access keys, and setting an alternate account contact. Creating EC2, RDS, S3, IAM users, and pipelines is not a root task.

If `aws sts get-caller-identity` returns an ARN ending in `:root`, deployment stops.

## Identity we want

Preferred: IAM Identity Center, or an IAM role assumed with temporary credentials. The caller ARN then looks like `arn:aws:sts::ACCOUNT:assumed-role/...`.

Acceptable for a lab if Identity Center is not available: one IAM user that is not root, MFA required, access keys created only after MFA is on, and a policy limited to the services for the current step. Long-lived keys are deleted at the end of the internship.

The deployment identity needs permission for the services in the approved step only. An `AdministratorAccess` lab user is still not root, and it is still broader than we want for day-to-day commands. We will narrow it once the account shape is known.

## MFA

MFA is required on root and on the human identity that can deploy. A virtual MFA application is enough. Console passwords without MFA are not an acceptable deployment path.

## Secrets

Do not paste access keys, secret keys, session tokens, passwords, or database URLs into chat, into Git, into screenshots, or into a public link.

Commands in this project will use the AWS CLI's configured profile or an instance role. A command line will not contain a secret value.

Standard Parameter Store parameters may hold non-secret configuration. Passwords and tokens belong in Secrets Manager, or they are not stored at all because IAM database authentication is being used.

## Billing safety

Before the first paid resource:

1. A budget or billing alarm at a ceiling you choose, with email to you.
2. A written list of the resources that step will create.
3. A destroy list for those same resources.
4. Your explicit approval.

The first AWS Budgets are included at no extra charge for the usual two-budget allowance. Confirm that allowance in the console when we reach that step. Confirm the current price of each resource the same day, in the region where it will be created.

## Checkpoint questions

1. **Why is the root user the wrong caller for CloudCart?**  
   Root is the account owner. An access key for root cannot be constrained by an IAM policy, so any leak is a full account compromise. Daily provisioning uses a separate identity whose permissions can be limited and revoked.

2. **What does `sts get-caller-identity` prove?**  
   It proves which principal the CLI is authenticated as, right now. It does not prove MFA is enabled, that the keys are unused elsewhere, or that the identity is least privilege.

3. **Why is an instance role safer than an access key on an EC2 instance?**  
   The instance role issues temporary credentials through the metadata service. They expire and rotate. An access key in a file remains valid until someone deletes it.

4. **Where does MFA have to exist before we build?**  
   On the root user, and on the human identity that will approve and run deployment commands.

5. **What will you send back from the first command, and what will you leave out?**  
   The ARN type and the region. Access keys, secret keys, and session tokens stay on the machine.
