# Task 5 — CloudFront, a private origin, and Lambda@Edge

Status: **LOCAL / DOCUMENTED. Not deployed.** Terraform defines Origin Access Control, a private S3 origin, an image cache policy, and a storefront distribution. The Lambda@Edge behavior is the Node functions in `application/edge-functions/`, tested with `node --test`. Those functions are not published and are not attached to the distribution. A cache hit ratio has not been read from CloudFront.

## Objective

Serve product images from a private S3 bucket through CloudFront, with caching, query cleaning, WebP conversion within the edge limits, and short-lived signed URLs.

## Requirements

1. A private S3 origin.
2. Origin Access Control.
3. Lambda@Edge.
4. Caching headers.
5. Filtering of malicious query parameters.
6. WebP conversion.
7. Short-lived signed URLs.
8. A check of the regional cache hit ratio.

## Design notes

The bucket does not allow `s3:GetObject` to `Principal: "*"`. CloudFront uses Origin Access Control, and the bucket policy allows `s3:GetObject` only for that distribution's source ARN.

Lambda@Edge functions are created in `us-east-1` and published as a numbered version. `$LATEST` cannot be associated. There are no user-defined environment variables. Viewer-request and viewer-response events time out at 5 seconds and are capped at 128 MB of memory. Origin-request and origin-response events time out at 30 seconds. A response generated on origin-response cannot exceed 1 MB, headers included.

WebP conversion runs on origin-response, and only for an image whose converted bytes stay under 1 MB. Larger masters are resized as part of that function or converted ahead of time into the bucket. The test set includes one image that converts and one that is over the limit, so the limit is part of the evidence rather than a surprise.

Query filtering is scoped to the image cache behavior. Stripping parameters on the storefront behavior would break EverShop. The function keeps an allow-list and drops the rest, so a cache key cannot be poisoned by unbounded parameters.

The cache policy and the origin response's `Cache-Control` header are set so CloudFront can cache the converted object. Cache statistics come from CloudFront popular-objects or cache-statistics reports for the distribution. A single request is not a hit ratio. The test generates a repeated request from one region and records the hit percentage the service reports.

Signed URLs are CloudFront signed URLs with a short expiry, for a private behavior. They are separate from S3 presigned URLs, which Task 6 uses for upload and download by the application.

Lambda@Edge has no free tier. A lab's handful of invocations is a small charge and still needs approval.

## Evidence to collect later

- Distribution, origins, and behaviors.
- Bucket policy showing the OAC principal and no public principal.
- OAC configuration.
- Lambda@Edge source and the published version ARN.
- Cache policy.
- Requests with a hostile query string, and the cleaned origin request or the blocked response.
- An image served as `image/webp`, and the oversized image's recorded fallback.
- A signed URL that works before expiry and fails after expiry.
- Cache statistics for the test window.

## Not done

No distribution or function version exists in AWS. The 1 MB origin-response guard is a LOCAL test. Cache-hit ratio remains BLOCKED until CloudFront reports it. Do not treat one request as a hit ratio.
