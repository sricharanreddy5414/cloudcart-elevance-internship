# Phase 0 — cost ledger and deployment plan

Date: 17 November 2026 (Asia/Calcutta).  
Commit inspected: `949ac49a7e0e05fc9081f66246fdd86d734e11f1`.  
Region intended later: `ap-south-1`, with CloudFront certificates and Lambda@Edge in `us-east-1`.  
Budget target: ₹500 per month, paid by the account. This is not permission to spend ₹500.

No resource was created. `terraform apply` was not run. `confirm_paid_deployment` remains false in every stack.

## Account check

This environment has no AWS CLI, no `~/.aws` directory, and no `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, or `AWS_SESSION_TOKEN`. The caller identity, MFA, and permissions were not read. Docker is also absent, so EverShop was not started here.

Deployment stays stopped until a non-root caller is identified. If that caller is `arn:aws:iam::ACCOUNT:root`, nothing is created. Do not paste access keys into chat.

The Windows CLI was not visible from this machine. Existing IAM, Identity Center, and unrelated projects were not changed.

## How the rupee figures were built

Market USD/INR on 17 November 2026 was about ₹93.48 per US dollar. AWS India invoices also add 18% GST when the billing address is in India. Payable rupees below are list price × 93.48 × 1.18, rounded. They are planning estimates, not a quote from the AWS Pricing Calculator for this account. Mumbai hourly rates move, and the account's free-tier or credit balance is unknown.

Accounts created on or after 15 July 2025 receive AWS credits instead of the old 750-hour RDS and load-balancer allowance. Accounts created earlier may still have legacy free tier. Neither status is known here, so the table assumes list price.

## Always-on month, required services, no NAT Gateway

This is the smallest shape that still contains the services the six tasks name: one public hosted zone, one health check, two WAF web ACLs with one managed rule group each, Multi-AZ `db.t3.micro` MySQL, two `t3.micro` instances, one Application Load Balancer, four public IPv4 addresses, a small S3 footprint, one secret, one pipeline, and light logs. NAT Gateway is excluded on purpose. A custom domain registration is also excluded.

| Resource | Basis | USD / month | Payable, with GST |
| --- | --- | ---: | ---: |
| Route 53 public hosted zone | $0.50 | 0.50 | ₹55 |
| Route 53 health check | $0.50 | 0.50 | ₹55 |
| WAF web ACL × 2 | $5 each | 10.00 | ₹1,103 |
| WAF managed rule group × 2 | $1 each | 2.00 | ₹221 |
| RDS MySQL Multi-AZ `db.t3.micro` | $0.049 × 730 hours | 35.77 | ₹3,945 |
| RDS gp3, 20 GB, one copy | $0.131 × 20 | 2.62 | ₹289 |
| EC2 `t3.micro` × 2 | Mumbai guide, about ₹620 each before GST | 13.26 | ₹1,463 |
| Public IPv4 × 4 | $0.005 × 730 × 4 | 14.60 | ₹1,611 |
| Application Load Balancer hours | $0.0239 × 730 | 17.45 | ₹1,925 |
| ALB capacity, light traffic | about $5 | 5.00 | ₹552 |
| EBS gp3, 8 GB × 2 | about $1.47 | 1.47 | ₹162 |
| S3, inventory, ECR | about $1 | 1.00 | ₹110 |
| CloudFront, inside the always-free 1 TB and 10 million requests | 0 | 0.00 | ₹0 |
| Secrets Manager, one secret | $0.40 | 0.40 | ₹44 |
| CodePipeline, one active pipeline | $1 | 1.00 | ₹110 |
| CodeBuild, one 15-minute small build | $0.075 | 0.08 | ₹9 |
| CloudWatch logs, light | about $2 | 2.00 | ₹221 |
| Lambda@Edge, a lab's requests | about $1 | 1.00 | ₹110 |
| ACM public certificates | 0 | 0.00 | ₹0 |
| **Total before a domain, NAT, data transfer, or a second RDS restore** |  | **about $109** | **about ₹12,000** |

Adding one NAT Gateway, which private subnets need if they pull images without VPC endpoints, is about $0.056 × 730 = $41 before data. That is about ₹4,500 with GST, and $0.045 or more per gigabyte processed. The Terraform stacks do not add a NAT Gateway today.

A point-in-time restore creates a second database and bills it until that instance and its snapshot are deleted. Glacier transitions have a 90-day minimum storage charge, so a short lab should not move objects to Glacier.

## Comparison with ₹500

₹500 including GST buys about $4.53 of AWS list price per month.

| Candidate left running for a month | Fits ₹500? |
| --- | --- |
| Static S3 origin plus CloudFront on `*.cloudfront.net`, inside the free request allowance, no public IPv4 | Yes, if traffic stays inside that allowance. This is not EverShop and not a custom domain. |
| Route 53 hosted zone alone | Yes, about ₹55. Useless until a domain exists. |
| One public IPv4 address | Almost the whole budget: about ₹475 with GST. |
| One WAF web ACL | No. About ₹650 with GST before any rules. |
| One Application Load Balancer | No. About ₹1,900 in hours alone. |
| Multi-AZ MySQL `db.t3.micro` | No. About ₹3,900 in instance hours alone. |
| The six-task stack above | No. About ₹12,000, roughly 24 times the target. |

A temporary `*.cloudfront.net` name can serve HTTPS during development. It does not complete Task 1. Task 1 needs a domain you control, a Route 53 zone, and two issued ACM certificates. No domain will be registered without a separate approval. A `.com` registration is about $14 for a year, plus GST, and it is not part of the ₹500 monthly run rate.

## What a short window would cost

The mentor has not confirmed that temporary resources and saved evidence are acceptable. This section is a price, not an approval.

The always-on stack is about $109 / 730 = $0.15 per hour. Six hours is about $0.90 of list price, about ₹100 with GST, if every billable object is deleted afterwards. That includes prorated WAF and Route 53. It does not include a forgotten snapshot, a Secrets Manager recovery window, a Glacier minimum, or a second RDS instance left from a restore.

RDS deletion protection is enabled in Terraform, and a final snapshot is required. The snapshot bills until it is deleted. Secrets Manager can keep charging through its recovery window unless the secret is deleted with no recovery window. Stopped EC2 instances still bill for EBS and for any public IPv4 that remains allocated.

## Phase plan

| Phase | Action now | Deploy? |
| --- | --- | --- |
| 0 Repository and identity | Inspected. Caller unknown. Cost recorded. | No |
| 1 Public site | Only a static CloudFront site fits the monthly budget. EverShop needs compute and PostgreSQL, which do not. | Wait |
| 2 Task 1 | Zone, two certificates, two WAF ACLs, health check, one distribution with origin failover. Blocked by domain ownership and by WAF's monthly price. | Wait |
| 3 Task 2 | Private Multi-AZ MySQL lab, separate from EverShop PostgreSQL. Five-minute RPO needs a measured restore, which creates another database. | Wait |
| 4 Task 3 | Real Auto Scaling activity needs the EC2 capacity from Task 4. In-process tests are not AWS chaos tests. | Wait |
| 5 Task 4 | ECR, ECS on EC2, ALB, Parameter Store, CodeBuild, CodePipeline. The ALB alone exceeds ₹500 for a month. | Wait |
| 6 Task 5 | CloudFront and OAC can be cheap. Lambda@Edge is not deployed until a function version in `us-east-1` is associated. | Wait |
| 7 Task 6 | Bucket features are cheap. Object Lambda is closed to new customers as of 7 November 2025. ClamAV definitions are not packaged. Glacier is a cost trap for a short lab. | Wait |
| 8 Submission | Portal form stays with you. | Not submitted |

Tasks 2, 3, and 4 share one VPC and the ECS capacity. They should not be six unrelated copies of a NAT Gateway, an ALB, or a database.

## Teardown checklist, for a later approved window

Do not run this now.

1. Save screenshots, CLI output, and resource IDs outside the account.
2. Remove secrets from those files.
3. Delete the restore database before the original database.
4. Disable deletion protection, delete the database, then delete the final snapshot and any manual snapshot.
5. Delete secrets with no recovery window only when the evidence no longer needs them.
6. Delete WAF associations, then both web ACLs.
7. Empty and delete S3 buckets, including inventory and pipeline artifacts.
8. Delete the load balancer, target groups, and public addresses.
9. Scale the Auto Scaling group to zero, then delete it, the launch template, and leftover EBS volumes.
10. Delete ECR images, the pipeline, CodeBuild, and log groups.
11. Delete the hosted zone only after records are removed. A zone deleted within 12 hours is not charged the $0.50.
12. Run a resource check for leftovers: NAT gateways, Elastic IPs, load balancers, RDS instances, snapshots, and secrets.

## Approvals required before any apply

1. Written mentor confirmation that a temporary deployment, followed by teardown, counts as evidence.
2. Your explicit approval of one named phase, with a ceiling in rupees and a maximum number of hours.
3. A non-root AWS caller on a machine this work can use, without pasting keys into chat.
4. A domain, only if you separately approve buying one.
5. Mentor decision on the MySQL lab staying separate from EverShop PostgreSQL.
6. Mentor decision on the ordinary-object thumbnail if this account cannot use S3 Object Lambda.

Until those exist, the stacks stay at zero resources.
