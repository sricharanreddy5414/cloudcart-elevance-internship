# Cost approval gate

Status: closed. No resource is approved. No resource has been created.  
Prices checked against AWS public pricing pages on 17 November 2026. Regional prices differ. Free-tier eligibility depends on when the account was opened and what it has already used. Recheck the pricing page and the account's free-tier balance on the day of any create.

A full CloudCart deployment cannot be run at ₹0. Several required services bill by the hour for as long as they exist, including hours when nobody is using them.

## Services that fit a careful lab

| Service | What it does for CloudCart | Charge | Cheaper option that still meets the brief |
| --- | --- | --- | --- |
| IAM, standard Parameter Store | Identity and non-secret config | No charge for standard parameters and IAM | None needed |
| ACM public certificates | HTTPS on CloudFront and the ALB | No charge | None needed |
| CloudFront data plane | Storefront and image delivery | Always-free allowance includes 1 TB out and 10 million HTTP/HTTPS requests per month, then paid | Stay inside that allowance |
| S3 Standard for a few images | Product images | Pennies, and a 12-month free allowance on eligible accounts (5 GB, limited requests) | Keep the lab bucket small and empty it when finished |

## Services that bill, and that the brief requires

List prices below are the common US East (N. Virginia) public rates used to estimate size. Mumbai can be higher. These are estimates, not a quote.

| Resource | Why it bills | Rough size if left running | Same-day lab, then deleted |
| --- | --- | --- | --- |
| NAT gateway, one AZ | About $0.045 per hour plus about $0.045 per GB processed | About $32 per month, before data. Two AZs roughly doubles the hourly charge. | A few hours is well under $1, and the bill continues until the gateway is deleted. |
| Application Load Balancer | Hourly charge plus load-balancer capacity units. Eligible newer accounts can have 750 hours and 15 LCUs per month. | About $16 per month plus capacity units when the free allowance does not apply. | Often $0 on an eligible free tier; otherwise well under $1 for an afternoon. |
| RDS Multi-AZ | Two database instances. Multi-AZ is outside the classic free-tier database allowance. Storage and backup storage are extra. A point-in-time restore creates another instance. | Tens of dollars per month for a small instance class, plus storage. | A few hours is small. The restored copy must be deleted or it becomes a second monthly instance. |
| EC2 for ECS | Instance hours plus EBS. The classic free tier is 750 hours per month of t2.micro or t3.micro, shared by every instance and region. | The second instance, larger types, and disks beyond the allowance bill. Spot is cheaper and is not free. A stopped instance still bills for its disk. | One small instance may fit the allowance. A mixed On-Demand plus Spot group will show a Spot charge. |
| Elastic IP left unused | Charged while it is not attached to a running instance | A few dollars per month | Release it the same day. |
| Route 53 hosted zone | $0.50 per month for each of the first 25 zones. The fee is charged when the zone is created and is not prorated, except a zone deleted within 12 hours is not charged. | $0.50 that month, even for a short test that overruns 12 hours. | Delete within 12 hours if the test is only a dry run. |
| Domain registration | Annual registration fee | A `.com` is typically in the low tens of US dollars per year. | Use a domain you already own. |
| Route 53 health check | Monthly charge per health check | About $0.50 per month for a basic check. Confirm the current health-check price before creating one. | Delete it with the zone. |
| AWS WAF | $5 per web ACL per month, $1 per rule or managed rule group per month, $0.60 per million requests. Prorated hourly. | Two web ACLs (CloudFront and ALB), each with one managed rule group, are about $12 per month before request charges. | An afternoon is a small fraction of that, and a forgotten web ACL bills all month. |
| Secrets Manager | $0.40 per secret per month plus $0.05 per 10,000 API calls | Under $1 for one database secret | Still a small monthly line until the secret is deleted. Pending deletion can be 7 to 30 days. |
| Lambda@Edge | No Lambda free tier. About $0.60 per million requests plus duration. | A lab's few requests are cents. | Keep the functions off unused distributions. |
| CodePipeline and CodeBuild | Pipeline and build-minute charges. The pricing model has changed before. | Confirm the live price before the first pipeline. | Run the minimum builds, then disable the pipeline. |
| S3 Intelligent-Tiering and Glacier transitions | Monitoring charge per object. Glacier classes add transition fees and minimum storage durations of 90 or 180 days. | A handful of lab objects can cost more in Glacier than in Standard. | Write the policy, and apply a lifecycle rule only after a separate approval. |
| Data transfer across Availability Zones | About $0.01 per GB each direction | Small in a lab, real under a load test | Keep the load test short and record the byte count. |

## What a forgotten lab costs

One NAT gateway, one ALB, one small Multi-AZ database, two small instances, two WAF web ACLs, and one hosted zone, left up for a month, is on the order of $80–150 before disks, data transfer, secrets, and pipeline minutes. The exact number depends on instance class, region, and free-tier eligibility. The expensive mistake is leaving them on, not the afternoon of testing.

## What ₹0 can still produce

- The architecture, threat notes, and interview explanations.
- Docker on the existing Windows project, without a second database volume.
- Infrastructure templates that are validated and never applied.
- Lambda and Lambda@Edge source code with local unit tests.
- A WAF rule document and a CodeBuild `buildspec.yml`.
- Evidence labeled **B. Simulated**. That label cannot be changed to **D. Verified** without a live AWS check.

Those artifacts do not satisfy a reviewer who asks for an ACM validation screenshot, an RDS console page, or a CloudFront cache-statistics graph.

## Approval record

| Date | Resource | Estimate you accepted | Approved by | Destroyed on |
| --- | --- | --- | --- | --- |
| — | None | — | — | — |

When you approve a resource, add a row here before the create command runs.
