# Task 6 — Private product-image storage

Status: **LOCAL / DOCUMENTED. Object Lambda is not deployed.** Terraform defines a private bucket, bucket-owner enforcement, AES256, public-access blocking, Intelligent-Tiering, Glacier, and weekly inventory. Presigned URLs, EICAR quarantine, and Pillow WebP thumbnails pass local tests. S3 Object Lambda was not called. New customers cannot start using it. The thumbnail path is an ordinary object, not Object Lambda.

## Objective

Store EverShop product images in a private, encrypted bucket; upload and download with presigned URLs; deliver public reads through CloudFront; tier cold objects; inventory the bucket; and scan new objects before they are served.

## Requirements

1. A private S3 bucket.
2. Bucket-owner-only access.
3. Encryption.
4. Presigned upload and download URLs.
5. CloudFront for public delivery.
6. S3 Object Lambda for on-demand thumbnails, or a documented feasibility assessment if it is unavailable.
7. Intelligent-Tiering and Glacier lifecycle policies.
8. S3 Inventory.
9. Malware scanning of new uploads with Lambda and ClamAV.

## Design notes

Block Public Access is enabled on the bucket. Object Ownership is bucket owner enforced, so ACL grants are disabled and the bucket owner owns every object. Default encryption is SSE-S3, or SSE-KMS if you later approve the key charge. The bucket policy denies non-TLS requests.

Presigned URLs are created by an IAM role for `PutObject` and `GetObject`, with a short expiry. The test uploads with the PUT URL, downloads with the GET URL, and shows a request after expiry failing. The URLs are not committed.

Public delivery reuses the Task 5 distribution and Origin Access Control. The bucket is not made public to satisfy this requirement.

**Object Lambda.** Since 7 November 2025, new customers cannot start using S3 Object Lambda. When an account is available, one API call will record whether this account can create an Object Lambda access point. If it cannot, the deliverable is the feasibility note plus thumbnails written by a normal Lambda on `s3:ObjectCreated`. Those derived objects are ordinary S3 objects. They will not be called Object Lambda results.

**Lifecycle.** Intelligent-Tiering and a transition to an S3 Glacier storage class are written as lifecycle rules. The legacy Amazon Glacier vault API is not used; it stopped accepting new customers on 15 December 2025. Glacier classes charge a minimum storage duration of 90 or 180 days. Applying that rule to lab objects needs its own approval, because it can cost more than S3 Standard for a one-week project.

**Inventory.** A second private bucket receives the inventory report. The report is an object listing, not a backup.

**Malware scan.** What exists is an EICAR test-string match. It is not signature scanning and it is not ClamAV. A miss is `eicar-negative`, which has false negatives for every other payload, including real malware, and false positives only for the EICAR string itself. The handler fails closed: a missing object body is `not-scanned`, an EICAR match goes to `quarantine/`, and every other object goes to `holding/`. `public` is never set. Promotion to `public/` requires a verdict of `approved`, which this code cannot emit. CloudFront is allowed to read only `public/*`.

ClamAV was not added. The definition database is large, the function would need a container image, roughly 1.5 GB to 3 GB of memory, and a cold start long enough to load signatures. A 5 MB object cap is enforced here. Lambda's own timeout ceiling is 15 minutes. A scanner error must not publish the object. None of that runtime has been deployed.

## Evidence to collect later

- Bucket settings: Block Public Access, ownership, encryption, policy.
- Presigned upload, download, and expiry.
- A CloudFront URL for a clean object, and a direct S3 URL that is denied.
- Object Lambda result, or the API error plus the thumbnail Lambda that replaced it.
- Lifecycle configuration JSON.
- An inventory report object.
- Scan logs for the clean file and the EICAR file, with the infected object out of the public prefix.

## Not done

No bucket, inventory report, or scanner function exists in AWS. `security/malware/handler.py` recognizes the EICAR test string only. It does not include ClamAV definitions. Label the scan LOCAL. Label Object Lambda BLOCKED pending mentor approval of the ordinary-object substitute.
