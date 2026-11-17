# Cost and deployment guardrails

No AWS resource has been created for CloudCart. Each Terraform stack defaults `confirm_paid_deployment` to false. `terraform plan` for all six stacks reported no changes on 17 November 2026.

`scripts/terraform-apply.ps1` exits with an error unless two switches are passed, and it still refuses after those switches. An approved apply has to be a separate command that names one stack.

## Charges if a stack is later applied and left running

Prices were checked against public AWS pages on 17 November 2026. Mumbai prices can differ. These are estimates.

| If you apply it | What starts billing | Rough monthly size if forgotten |
| --- | --- | --- |
| Task 1 | Hosted zone about $0.50. Two WAF web ACLs about $5 each, plus $1 for each managed rule group. Health check about $0.50. A domain registration is a separate annual fee and is not in this Terraform. | About $13 plus the zone, before request charges. |
| Task 2 | Multi-AZ `db.t3.micro` MySQL is outside the classic free-tier database allowance. Storage, backups, and one Secrets Manager secret add to it. A restore creates another instance. | Tens of dollars. |
| Task 3 | On-Demand and Spot instances, plus EBS. Spot is discounted and is not free. | Depends on the hours you leave the group running. |
| Task 4 | Application Load Balancer, ECS container instances, CloudWatch logs, CodeBuild minutes, ECR storage. | The load balancer is on the order of $16 per month when free-tier hours do not apply. |
| Task 5 | CloudFront has a large free allowance. Lambda@Edge has no free tier. A lab's few requests are cents. | Small if the functions are not attached to a busy distribution. |
| Task 6 | S3 storage is small. Glacier transitions have minimum storage durations of 90 days or more, so a short test can cost more than leaving objects in Standard. | Small until a lifecycle rule moves lab objects. |

A NAT gateway is not in the default network. Adding one is about $32 per month per Availability Zone before data charges. Do not add it without a separate approval.

## Delete considerations

- A Route 53 hosted zone deleted within 12 hours is not charged. After that, the $0.50 monthly charge applies.
- RDS deletion protection is on. A final snapshot is required. The snapshot bills until it is deleted.
- Secrets Manager secrets can remain billable through a recovery window after deletion.
- WAF web ACLs bill until they are deleted.
- An unused Elastic IP bills. This design does not allocate one.
- EBS volumes continue to bill after an instance is stopped.

## Local validation credentials

The provider blocks use the literal `local-validate-only` so `terraform plan` can run without account credentials. They are not an AWS account key. Set `local_validate_credentials` to false only for an approved apply that uses your own non-root profile from the environment, not from a file in git.
