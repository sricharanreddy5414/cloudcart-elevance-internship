# Task tracker

Updated: 17 November 2026 (Asia/Calcutta).

A task is completed only when the evidence folder for that task contains real outputs that meet the brief. No task is completed.

Status values used below:

| Status | Meaning |
| --- | --- |
| Not started | No implementation and no evidence. |
| In progress | The current step is underway. |
| Implemented locally | Built and tested on the Windows Docker host. |
| Simulated and tested | AWS-like behavior was exercised without creating the AWS service. |
| Deployed to AWS | The named service exists in the account. |
| Verified | Live evidence was checked against the requirement. |
| Blocked | A specific gate stops the work. The blocker is written down. |

| ID | Task | Status | Blocker |
| --- | --- | --- | --- |
| 0 | Account identity, MFA, non-root deployment principal | In progress | Waiting for `aws sts get-caller-identity` from the Windows CLI. |
| 1 | Route 53, ACM, HTTPS, HSTS, WAF, maintenance failover | Not started | No non-root identity. No domain decision. No spend approval. Hosted zone and WAF have charges. |
| 2 | Private Multi-AZ database, IAM auth, TLS, rotation, 5-minute RPO | Not started | EverShop supports PostgreSQL only. The brief says MySQL. Mentor decision required. Multi-AZ has a charge. |
| 3 | Mixed-instance Auto Scaling, lifecycle hooks, chaos tests | Not started | Depends on the ECS/EC2 capacity from Task 4. Instances have a charge. |
| 4 | ECR, ECS on EC2, ALB, Parameter Store, CodePipeline, blue/green | Not started | ALB, EC2, and the pipeline have charges. Blue/green is not claimed until traffic is switched and rolled back under test. |
| 5 | Private S3 origin, OAC, Lambda@Edge, cache, signed URLs | Not started | Lambda@Edge has no free tier. WebP at the edge is limited to a 1 MB origin-response. |
| 6 | Private S3 images, presign, lifecycle, inventory, malware scan | Not started | S3 Object Lambda is closed to new customers as of 7 November 2025. Feasibility check is part of the task. |
| 7 | Final report, evidence index, 2–5 minute demo | Not started | Blocked until the evidence is real. Submission is one-time. |

## Local application

| Item | Status |
| --- | --- |
| Windows tools installed | Reported complete. Not rechecked here. |
| EverShop and PostgreSQL containers | Reported healthy, admin login successful. Not rechecked here. |
| Store settings and product catalog | Not started. |
| Production Dockerfile | Not started. The development Compose file will be read before any edit. |
| Administrator password rotation | Required. The password appeared in terminal output. |
