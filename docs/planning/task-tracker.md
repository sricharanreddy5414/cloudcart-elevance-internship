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
| 1 | Route 53, ACM, HTTPS, HSTS, WAF, maintenance failover | Simulated and tested | No non-root identity. No domain decision. No spend approval. Hosted zone and WAF have charges. |
| 2 | Private Multi-AZ database, IAM auth, TLS, rotation, 5-minute RPO | Simulated and tested | EverShop supports PostgreSQL only. The brief says MySQL. Mentor decision required. Multi-AZ has a charge. |
| 3 | Mixed-instance Auto Scaling, lifecycle hooks, chaos tests | Simulated and tested | Depends on the ECS/EC2 capacity from Task 4. Instances have a charge. The chaos test is in-process. |
| 4 | ECR, ECS on EC2, ALB, Parameter Store, CodePipeline, blue/green | Implemented locally | ALB, EC2, and the pipeline have charges. Blue/green is simulated. Docker did not build the image in the Linux validation environment. |
| 5 | Private S3 origin, OAC, Lambda@Edge, cache, signed URLs | Simulated and tested | Lambda@Edge has no free tier. The functions are not attached to the distribution. WebP at the edge is limited to a 1 MB origin-response. |
| 6 | Private S3 images, presign, lifecycle, inventory, malware scan | Simulated and tested | S3 Object Lambda is closed to new customers as of 7 November 2025. The scan matches EICAR only. |
| 7 | Final report, evidence index, 2–5 minute demo | In progress | The report and index exist. The video does not. Submission is one-time. |

## Local application

| Item | Status |
| --- | --- |
| Windows tools installed | Reported complete. Not rechecked here. |
| EverShop and PostgreSQL containers | Reported healthy, admin login successful. Not rechecked here. |
| Store settings and product catalog | Not started. |
| Production Dockerfile | Present at `application/docker/Dockerfile`. Not built where Docker is missing. |
| Administrator password rotation | Required. The password appeared in terminal output. |
