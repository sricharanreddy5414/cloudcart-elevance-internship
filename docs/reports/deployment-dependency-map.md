# Deployment dependency map

The six Terraform stacks do not share one VPC. Task 2 builds its own network. Task 4 expects a VPC id, subnet ids, and an image digest as variables. Applying every stack at once is not a supported step, and it is not approved.

## Shared pieces

| Piece | Used by | Notes |
| --- | --- | --- |
| EverShop PostgreSQL volume `postgres-data` | The existing Windows store | Not a Terraform resource. Not Task 2. Do not delete it. |
| Domain name and `us-east-1` certificate | Tasks 1 and 5 | No domain is registered. |
| ALB | Tasks 1, 3, and 4 | Task 4 defines one. Tasks 1 and 3 expect its identifiers. |
| Private image bucket | Tasks 5 and 6 | Task 6 defines it. Task 5 expects its regional domain name. |
| Paid-deployment gate | All six stacks | Default false. |

## What can be validated without AWS

| Task | Local evidence that exists | Genuine AWS evidence still required |
| --- | --- | --- |
| 1 | Terraform plan, HSTS and redirect unit checks | A hosted zone, issued certificates, a failover change, both WAF web ACLs |
| 2 | Token shape, rotation steps, TLS rejection, RPO calculator | A private Multi-AZ instance, an IAM login, `LatestRestorableTime` |
| 3 | In-process capacity model | An Auto Scaling group, a termination, a load test |
| 4 | Pinned Dockerfile text, blue/green model | A built image, ECR, ECS on EC2, a CodeDeploy shift |
| 5 | Node tests of the four functions | A distribution, a published edge version, a cache report |
| 6 | Presign, EICAR holding, Pillow thumbnail | A private bucket, inventory output, and a real scanner if the brief still requires ClamAV |

## Recommended order

Do not start with all six.

1. Keep running the local Python and Node checks. They do not create resources.
2. On the Windows Docker host, build `cloudcart-evershop:local` without removing `postgres-data`. That is Task 4's missing local proof. It is not an AWS deployment.
3. The first short AWS window that meets a mandatory paid service is Task 1, and only after a domain and a rupee ceiling are approved. It can be demonstrated with the maintenance origin before ECS exists.
4. Task 6's bucket can be a separate small window. It does not require the domain. It does not satisfy Object Lambda.
5. Task 2 is independent of the store and is the expensive database window. Do not run it in the same hours as the ALB and WAF.
6. Tasks 3 and 4 belong together later: the group launches the ECS instances, and the service needs the image, the load balancer, and the PostgreSQL endpoint. That window is the largest.
7. Task 5 attaches to the bucket from Task 6 and, for the storefront, to the load balancer from Task 4. Lambda@Edge is a separate publish in `us-east-1`.

## Prerequisites before any apply

A non-root IAM identity, a named rupee ceiling, `confirm_paid_deployment=true` for that one stack only, real values in place of the zero account ids, and a written teardown time. None of those is true now.
