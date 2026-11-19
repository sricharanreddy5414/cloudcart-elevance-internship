# Security design

Label: DOCUMENTED. No control in this note has been observed in a live AWS account.

## What is protected

Shopper sessions, the EverShop PostgreSQL data, the separate MySQL security-lab credentials, and product images. The Windows PostgreSQL volume `postgres-data` is application data and is not part of the MySQL lab.

## Trust boundaries

| Boundary | Control in the repository | Proven in AWS |
| --- | --- | --- |
| Internet to the store | HTTPS redirect and HSTS on the CloudFront response-headers policy. WAF managed rule groups on CloudFront and on the ALB. | No |
| Internet to images | Bucket owner enforced, Block Public Access, TLS deny, CloudFront OAC for `public/*` only. | No |
| Store to PostgreSQL | EverShop uses the existing PostgreSQL service. The password stays in an untracked `.env`. | Local store was not reachable from the validation environment |
| Application to MySQL lab | Private subnets, no public address, security group on 3306, `require_secure_transport`, IAM token or a rotated password. | No |
| Pipeline to production | CodeBuild and CodePipeline use their own roles. The ECS execution role is not reused for the build. Image tags are immutable. | No |
| Uploads | Presigned PUT expires and is limited to `incoming/`. EICAR payloads go to `quarantine/`. An EICAR miss stays in `holding/` and is not public. | LOCAL test only. Not ClamAV. |

## Threats considered

- A public bucket or an ACL grant would expose product images. Ownership is bucket-owner enforced, which disables ACLs.
- A stolen database password remains useful until rotation. An IAM database token expires in 15 minutes. The two logins are different users and are not interchangeable.
- A query string on the image behavior can poison the cache. The edge filter keeps `w`, `h`, `format`, and `q`.
- An origin-response function that rewrites a large image can exceed the Lambda@Edge 1 MB limit. The WebP function refuses that body.
- Root credentials can change every control and cannot be limited by an identity policy. No stack is applied until the caller is known to be a non-root principal.
- The malware handler matches the EICAR test string. It does not contain a current ClamAV database, so it is not a claim about detecting other malware.

## Secrets

`.env`, private keys, and Terraform state are gitignored. `.env.example` contains the placeholders `replace-with-a-local-password` and similar text. Terraform validation uses the non-functional strings `localvalidateonlykey` and `local-validate-only` so `terraform validate` can run without an AWS account. Those strings are not account keys.
