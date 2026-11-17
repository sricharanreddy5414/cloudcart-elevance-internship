# CloudCart

Elevance Skills — Cloud Technology internship

Author: Sri Charan Reddy  
Institution: Alliance University, Bengaluru  
Programme: BTech Computer Science and Engineering (Cloud Computing)  
Deadline: 17 December 2026  
Report status: draft. This is not the submission. The portal has not been used.

Enrollment number: [to be added]

## Contents

1. Introduction
2. Objectives
3. Technology
4. Architecture
5. The six tasks
6. Testing
7. Results
8. Limitations
9. Cost
10. Conclusion
11. References

## 1. Introduction

CloudCart is one store, EverShop, with six infrastructure tasks around it: DNS and edge security, a database security demonstration, capacity and failure testing, immutable container delivery, content delivery, and private product images.

The store's working database is PostgreSQL. The internship text asks for MySQL. Those facts are both kept. EverShop was not pointed at MySQL. A separate MySQL design covers the security controls in Task 2.

## 2. Objectives

- Keep the running EverShop installation intact.
- Implement each task in code that can be reviewed and tested without an AWS bill.
- Refuse to describe local results as AWS resources.
- Leave a path to deploy one approved stack at a time.

## 3. Technology

EverShop, Docker Compose, PostgreSQL 16, MySQL 8 in a separate lab definition, Terraform 1.9.8 with the AWS provider 5.74.0, Python 3.12, Node.js 22, botocore for local SigV4, and Pillow for thumbnails.

## 4. Architecture

Shoppers would resolve a Route 53 failover name. The primary answer is CloudFront in front of an Application Load Balancer and EverShop on ECS. The secondary answer is a static maintenance site. Product images stay in a private bucket and are read through Origin Access Control. The diagrams are in `docs/ARCHITECTURE.md`.

None of those AWS resources has been created.

## 5. The six tasks

### Task 1

Terraform defines the hosted zone, two ACM certificates, HSTS, HTTP-to-HTTPS redirection, two WAF web ACLs with the AWS common rule set, and failover records. The CloudFront certificate uses the us-east-1 provider. The ALB certificate does not. No domain is registered. A unit test shows that a failed primary record is still cached until the TTL expires.

### Task 2

Terraform defines a private Multi-AZ MySQL instance, IAM authentication, `require_secure_transport`, a Secrets Manager-managed master password, backups, and the MariaDB audit plugin option used by RDS for MySQL. The local harness rotates a password user, rejects a non-TLS login, and refuses to rotate the IAM user. The RPO function can show a four-minute lag against a supplied timestamp. It records that RDS was not restored.

### Task 3

Terraform defines a mixed On-Demand and Spot group, a launch lifecycle hook whose default is ABANDON, and target-tracking policies for CPU and ALB request count. The local model refuses to register an instance before schema and warm-up flags are set. Removing one zone leaves the other zone serving. Removing both zones drops availability. The report does not call that zero downtime.

### Task 4

The Dockerfile pins the EverShop index digest observed on Docker Hub on 17 November 2026. ECR is immutable and scans on push. The ECS service uses the EC2 launch type and the CodeDeploy controller. The local release model keeps production on blue when green is unhealthy, and shifts only when green is healthy. The image was not built in the environment that lacked Docker.

### Task 5

Terraform defines Origin Access Control, a cache policy that allows only `w`, `h`, `format`, and `q`, and redirect-to-https. Node tests cover query filtering, cache headers, the 1 MB conversion ceiling, and a signed URL that fails at expiry. The functions have not been published to Lambda@Edge.

### Task 6

Terraform defines a private, encrypted, versioned bucket, bucket-owner enforcement, Intelligent-Tiering and Glacier transitions, and a weekly inventory. Tests generate a 120-second presigned URL against a local endpoint, quarantine an EICAR payload, and write a WebP thumbnail with Pillow. Object Lambda is documented as unavailable to new customers. The thumbnail function is not Object Lambda.

## 6. Testing

`python scripts/run_validation.py` runs the Python tests, the Node edge tests, and Terraform validate plus plan for each stack. The machine-readable result is `evidence/test-results/validation-report.json`.

During construction, 31 Python tests and 8 Node tests passed, and all six stacks validated with a plan that added nothing. The committed report is the run taken after the final edit. If a later run disagrees, the JSON file is the one to trust.

## 7. Results

| Area | Result |
| --- | --- |
| AWS resources | None created. |
| Terraform plan | No changes while the paid-deployment flag is false. |
| Presign, quarantine, thumbnail | Passed locally. |
| Edge functions | Passed locally. |
| Blue/green model | Passed locally. Rollback was exercised. |
| Chaos model | Passed locally. Full zone loss reduced availability. |
| EverShop on this environment | Not running. Connection to port 3000 was refused. |
| Docker build | Not run. The Docker binary was absent. |

## 8. Limitations

- Local tests are not console screenshots.
- The five-minute RPO has not been verified on RDS. Restore time was not measured.
- ClamAV's signature database is not packaged. The scanner recognises the EICAR test string.
- WebP conversion at the edge is guarded by the 1 MB origin-response limit. Pillow proved a local thumbnail. Lambda@Edge was not deployed.
- S3 Object Lambda was not available to test for a new account.
- Private ECS instances cannot pull images until NAT or VPC endpoints are approved. Those have their own charges.
- The Windows store was not rechecked from the environment that wrote this report.

## 9. Cost

The guardrails are in `docs/COST_AND_DEPLOYMENT_GUARDRAILS.md`. A full deployment left running is not free. No charge has been incurred by this repository.

## 10. Conclusion

CloudCart is implemented as reviewable infrastructure and as tests that run without an account. It is not a deployed AWS system. The remaining work is an approved, time-boxed apply for the stacks that the mentor accepts, with evidence captured from those real resources and with the existing EverShop volume left in place.

## 11. References

- EverShop system requirements: https://evershop.io/docs/development/getting-started/system-requirements
- RDS IAM database authentication: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.html
- S3 Object Lambda availability: https://docs.aws.amazon.com/AmazonS3/latest/userguide/amazons3-ol-change.html
- AWS WAF pricing: https://aws.amazon.com/waf/pricing/
- Route 53 pricing: https://aws.amazon.com/route53/pricing/
- VPC pricing, including NAT Gateway: https://aws.amazon.com/vpc/pricing/
