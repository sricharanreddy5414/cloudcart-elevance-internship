# Task 1 — Route 53, ACM, and WAF

Status: **Not started.** Nothing in Route 53, ACM, or WAF has been created.

## Objective

Give CloudCart a domain, trusted HTTPS, HSTS, a managed web application firewall on both entry points, and an automatic DNS failover to a static maintenance site.

## Requirements

1. Custom domain in Amazon Route 53.
2. ACM certificates.
3. The CloudFront certificate is requested in `us-east-1`.
4. The Application Load Balancer certificate is requested in the workload region, `ap-south-1`.
5. HTTPS is enabled.
6. HSTS is enabled.
7. Failover to a CloudFront static maintenance website.
8. AWS WAF managed rules on CloudFront and on the ALB.

## How it fits

Shoppers resolve the domain in Route 53. The primary answer is the storefront CloudFront distribution. The secondary answer, used when the health check fails, is the maintenance distribution. CloudFront talks to the ALB for HTML and to the private image bucket for product images. WAF is associated with the distributions and, separately, with the ALB.

## Design notes

- DNS validation is the method for both certificates. The validation records live in the same hosted zone.
- CloudFront can use only an `ISSUED` certificate from `us-east-1`. A certificate in Mumbai cannot be attached to a distribution.
- Two web ACLs are required because a CloudFront-scope ACL and a regional ACL are different objects.
- HSTS is a response-headers policy on CloudFront. Early tests use a short `max-age`. The domain is not added to the preload list.
- Failover speed is limited by the record TTL and by resolver caches. The test records both. It does not claim an instant cutover.
- The maintenance origin is a private S3 bucket with Origin Access Control, consistent with Task 5 and Task 6.
- A hosted zone costs $0.50 for the month unless it is deleted within 12 hours. WAF web ACLs and managed rule groups have monthly charges, prorated hourly. A domain registration is an annual fee. ACM public certificates have no charge.

## Evidence to collect later

- Architecture diagram for this path.
- Hosted zone and records.
- Both certificates in `ISSUED` state, with their regions visible.
- An HTTPS response from the domain.
- A response that includes `strict-transport-security`.
- Both web ACLs, the managed rule group on each, and the associated resource.
- A failover test: health check failing, DNS answer changing to the maintenance distribution, then recovery.

## Security

The zone is the control point for the domain. Certificate validation records and the registrar settings stay with the account owner. WAF is attached before the distribution is used for anything beyond a test. Security group and WAF changes have a rollback: disassociate the web ACL, or revert the record to the previous alias.

## Not done

No zone, no certificate, no distribution, no web ACL, no test.
