# Decision log

Decisions are proposals until they are accepted. Nothing here has been deployed.

## D-001 — Database engine

- Status: proposed, waiting for the mentor.
- Fact: EverShop requires PostgreSQL 13 or newer. The project docs and the maintainers state that MySQL is not supported. The local stack is PostgreSQL 16. Source: [EverShop system requirements](https://evershop.io/docs/development/getting-started/system-requirements) and [discussion 641](https://github.com/evershopcommerce/evershop/discussions/641).
- Fact: The internship brief asks for MySQL RDS, and also asks for one integrated EverShop platform.
- Proposal: Implement every Task 2 control on Amazon RDS for PostgreSQL, because that is the engine EverShop can use. IAM database authentication, `rds.force_ssl`, Secrets Manager rotation, Multi-AZ, private subnets, and point-in-time recovery are supported on RDS for PostgreSQL.
- What we will not do: Invent a MySQL driver for EverShop, or point EverShop at MySQL and call it working.
- Open question: Whether the evaluator also requires a separate MySQL instance that the store does not use. A second database would add cost and would not be the store database.

## D-002 — S3 Object Lambda

- Status: proposed.
- Fact: As of 7 November 2025, S3 Object Lambda is available only to existing customers and selected partners. New customers cannot onboard. Source: [AWS availability change](https://docs.aws.amazon.com/AmazonS3/latest/userguide/amazons3-ol-change.html).
- Proposal: When an account exists, try the API once and save the real error or the real success. If the account is ineligible, deliver the feasibility assessment the brief allows, and generate thumbnails with a normal Lambda function on upload. That Lambda writes a derived object into a private prefix. It will be labeled as a Lambda thumbnail, not as Object Lambda.
- AWS names CloudFront dynamic image transformation, a Lambda function URL, and client-side processing as alternatives. Any alternative we build will be named as that alternative.

## D-003 — Glacier means S3 storage classes

- Status: accepted as terminology, not yet configured.
- Fact: The standalone Amazon Glacier vault service stopped taking new customers on 15 December 2025. S3 Glacier Instant Retrieval, S3 Glacier Flexible Retrieval, and S3 Glacier Deep Archive remain S3 storage classes and are configured with S3 Lifecycle.
- Rule: Task 6 lifecycle policies will use S3 storage classes. They will not use the legacy vault API.
- Cost rule: Glacier classes have minimum storage durations (90 or 180 days) and transition fees. A short lab that transitions tiny objects into Glacier can cost more than leaving them in S3 Standard. The lifecycle document will be written before any rule is applied, and a lab rule needs its own approval.

## D-004 — No silent spend

- Status: accepted.
- Rule: A resource is created only after a written note of what it does, whether it bills, a list-price estimate, a cheaper option, and an explicit approval for that resource.
- Rule: Approval for one resource is not approval for the whole architecture.

## D-005 — Evidence labels

- Status: accepted.
- Rule: Every result is labeled A (local), B (simulated), C (deployed), or D (live-verified). A simulated result is never described as a deployment.

## D-006 — Regions

- Status: proposed.
- Workload region: `ap-south-1` (Mumbai), closest commercial region to Bengaluru.
- `us-east-1` is used for the CloudFront ACM certificate, the CloudFront-scope WAF web ACL, and Lambda@Edge, because those services require that region.
- Route 53, IAM, and CloudFront are global.

## D-007 — HSTS preload

- Status: accepted.
- HSTS will be sent and verified.
- The domain will not be submitted to the browser preload list during this internship. Preload is hard to undo and can lock a lab domain in HTTPS for a long time.

## D-008 — Migrations before target registration

- Status: implemented in the Task 3 hook and user data. Not deployed.
- The brief requires warm-up and database migration activity before an instance registers with the load balancer target group.
- Running schema migrations from every new instance at once can corrupt a database.
- Intended design: the pipeline runs migration once under a database lock. The Auto Scaling lifecycle hook holds the new instance and continues only after the schema version matches the image and the local process is warm. Then the instance may receive tasks and target-group registration.

## D-009 — Two different database logins

- Status: accepted as the Task 2 design.
- IAM database authentication and Secrets Manager password rotation will be demonstrated on two different database users.
- On PostgreSQL, granting `rds_iam` to a user makes IAM authentication take over for that user. The rotating password user stays a normal password user.

## D-010 — Leave the running Compose project alone

- Status: accepted.
- The existing `docker-compose.yml`, the `myevershop` network, and the `postgres-data` volume stay in place until a specific step reads them and says what will change.
- A production image is a new file. It does not replace the development Compose file by accident.
