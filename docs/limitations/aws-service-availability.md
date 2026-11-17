# AWS service availability

Checked against AWS documentation on 17 November 2026. No account API was called, because a create or a describe against a new service can be mistaken for a deployment attempt. Eligibility for this specific account is therefore not proven.

| Service | Availability | How CloudCart treats it |
| --- | --- | --- |
| S3 Object Lambda | Maintenance mode from 7 November 2025. New customers cannot start using it. Existing customers can continue for a limited time. | BLOCKED as a new deployment. Substitute: a normal function writes a WebP thumbnail object. That object is not an Object Lambda result. Mentor approval is required before calling the substitute the accepted design. |
| Amazon Glacier vaults | The standalone Glacier vault API stopped accepting new customers. S3 Glacier storage classes remain the lifecycle mechanism. | The lifecycle rule uses the `GLACIER` storage class. It does not create a Glacier vault. |
| ACM public certificates | Still available. Issuance requires a domain the account can validate. | DOCUMENTED in Terraform. Not requested. |
| Lambda@Edge | Still available. Functions must be published in `us-east-1`. No environment variables. Origin-response body limit is 1 MB. | Source and local tests exist. The function is not published. |
| RDS MySQL and PostgreSQL | Both still available. Multi-AZ is billable. | MySQL is the security lab. EverShop stays on PostgreSQL. Neither is created. |
| WAF, ALB, NAT, Route 53 hosted zones | Available and billable. A hosted zone is about $0.50 per month unless deleted within 12 hours. | Not created. `confirm_paid_deployment` defaults to false. |

Source for Object Lambda: [Amazon S3 Object Lambda availability change](https://docs.aws.amazon.com/AmazonS3/latest/userguide/amazons3-ol-change.html).
