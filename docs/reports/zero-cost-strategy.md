# Zero-cost review

Updated 19 November 2026 (Asia/Calcutta). Budget target: ₹0. No resource was created while writing this note.

Do not assume Free Tier eligibility. Accounts created on or after 15 July 2025 receive credits instead of the older 750-hour EC2, RDS, and load-balancer allowances. This account's age and credit balance were not read. Public IPv4 addresses are $0.005 per hour and are not free. Prices below use about ₹93.48 per US dollar and 18% GST, from the 17 November 2026 rate, and are estimates.

| Task | Required services | Free only if | Paid even then | Minimum if created | ₹0? |
| --- | --- | --- | --- | --- | --- |
| 1 | Route 53 zone, domain, two ACM certificates, two WAF web ACLs, health check, maintenance CloudFront and S3, ALB for the regional WAF | ACM certificates are free. A zone deleted within 12 hours is not charged $0.50. | Domain registration, about $14 for a .com year. WAF is $5 per web ACL and $1 per managed rule group. ALB hours and public IPv4. | About ₹40 for six hours of WAF plus ALB, plus about ₹1,550 once for a .com. A full month is about ₹4,800. | No |
| 2 | Multi-AZ MySQL, private subnets, IAM auth, TLS, Secrets Manager, EC2 client, a restore | None of the database hours are in the single-AZ free allowance. | Multi-AZ `db.t3.micro` is about $0.049 per hour. One secret is $0.40 per month. A restore bills a second instance. The final snapshot bills until deleted. | About ₹3,900 per month for the instance pair. Six hours is about ₹30 before the second restore instance. | No |
| 3 | Auto Scaling, On-Demand, Spot, lifecycle hook, CPU and request policies | Spot is a discount, not a waiver. | Instance hours, EBS, and public IPv4. | One `t3.micro` plus one IPv4 is about ₹1.56 per hour with GST. | No |
| 4 | ECR, ECS on EC2, ALB, SSM, CodeBuild, CodePipeline | SSM standard parameters have no charge. A tiny ECR image can fall inside a small free storage allowance on some accounts. | ALB, EC2, IPv4, CodeBuild minutes, and usually $1 per active pipeline. | The ALB alone is about ₹1,900 per month. | No |
| 5 | CloudFront, OAC, Lambda@Edge, signed URLs | CloudFront's always-free allowance is 1 TB out and 10 million requests per month. | Lambda@Edge has no free tier. A lab's requests are cents, not a guaranteed zero. | A few test requests are likely under ₹10 if nothing else is attached. The functions are not associated yet. | No, not as a guaranteed zero |
| 6 | Private S3, presign, lifecycle, inventory, Object Lambda, ClamAV | A few standard objects can be inside a free storage allowance when the account has one. | Object Lambda is not sold to new customers. Glacier has a 90-day minimum. Lambda invocations for a scanner are billed. | Bucket storage for a lab is about ₹1. Object Lambda cannot be bought. | No |

Cleanup that must happen after any later approved window: delete web ACLs, load balancers, databases, snapshots, secrets, public addresses, instance volumes, and buckets. A Secrets Manager secret can keep billing through its recovery window. RDS deletion protection is on, and the required final snapshot bills until it is deleted.

The first deployment is not proposed for execution. The smallest later window that still uses a mandatory paid service is six hours of Task 1 after a domain is approved: about ₹40 of infrastructure plus the annual domain fee. That window is not approved.
