# Edge functions

Status labels for this directory:

| File | Label |
| --- | --- |
| `query-filter.js` | SOURCE READY, LOCALLY TESTED |
| `cache-headers.js` | SOURCE READY, LOCALLY TESTED |
| `webp.js` | SOURCE READY, LOCALLY TESTED. Conversion is not packaged. |
| `signed-url.js` | SOURCE READY, LOCALLY TESTED. Must not be published as Lambda@Edge. |

None of these files are DEPLOYMENT READY, AWS DEPLOYED, or AWS VERIFIED. A deployment-ready function would be a zip or container, an IAM role, a published version in `us-east-1`, and an association on the distribution. This directory has the source and `node --test` only.

Lambda@Edge constraints that this source already respects: no environment variables, no AWS SDK, viewer-request does not read a body, and the WebP path refuses a body at or above 1,000,000 bytes. The image cache policy whitelists `w`, `h`, `format`, and `q`. Signed URL parameters are preserved by the filter and are not part of that cache whitelist.
