# Phase 2 cost by resource

Estimates for `ap-south-1` unless noted. USD/INR is about ₹93.48. GST at 18% is included in the rupee columns. These are planning figures, not a calculator quote for this account. Free Tier and credits are not assumed. Nothing in this table has been created.

Hourly figures are list price divided by 730 where the published price is monthly.

| Resource | Why it is required | 1 hour | 3 hours | 6 hours | Month | After delete |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| Route 53 zone | Task 1 DNS | ₹0.08 | ₹0.23 | ₹0.46 | ₹55 | ₹0 if deleted within 12 hours |
| Domain registration | Task 1 custom name | n/a | n/a | n/a | about ₹1,550 for a .com year | Usually not refundable |
| ACM certificates × 2 | CloudFront must use us-east-1. ALB uses ap-south-1 | ₹0 | ₹0 | ₹0 | ₹0 | None |
| WAF web ACL × 2 plus one managed group each | Task 1 on CloudFront and the ALB | ₹1.81 | ₹5.43 | ₹10.86 | ₹1,324 | Bills until both ACLs are deleted |
| Route 53 health check | Failover | ₹0.08 | ₹0.23 | ₹0.46 | ₹55 | Bills until deleted |
| ALB hours, light LCU, two public IPv4 | Tasks 1, 3, and 4 | ₹4.08 | ₹12.24 | ₹24.48 | ₹2,980 | Addresses bill if they stay allocated |
| Multi-AZ MySQL `db.t3.micro` plus 20 GB | Task 2 | ₹5.40 | ₹16.20 | ₹32.40 | ₹3,940 | Final snapshot and a restore instance bill until deleted |
| Secrets Manager, one secret | Task 2 rotation | ₹0.06 | ₹0.18 | ₹0.36 | ₹44 | Recovery window can continue billing |
| Two `t3.micro` plus two IPv4 and small EBS | Tasks 3 and 4 | ₹3.20 | ₹9.60 | ₹19.20 | ₹2,340 | EBS bills after stop. Spot is a discount, not zero |
| S3, ECR, CloudFront inside the free request allowance | Tasks 5 and 6 | under ₹1 | under ₹1 | under ₹1 | under ₹110 | Glacier minimum duration if a transition runs |
| CodePipeline plus one 15-minute build | Task 4 | ₹0.16 | ₹0.16 | ₹0.16 | ₹119 | Pipeline bills while it exists |
| Lambda@Edge, a short test | Task 5 | under ₹1 | under ₹1 | under ₹10 | under ₹110 | No monthly fee after the functions are removed |

A month of the required services together is still about ₹12,000 with GST. Do not start all six at once.

The lowest later window that still uses a mandatory paid service is Task 1 for six hours: about ₹40 of WAF, ALB, and addresses, plus the domain fee if you approve a name. That window is not approved. Verify the WAF and ALB rates on the AWS pricing pages before any apply.
