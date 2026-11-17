# Task 6 — Private product-image storage

Status: **Not started.** No bucket has been created.

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

**Malware scan.** S3 event notification starts a Lambda function packaged as a container image, because the ClamAV signature database does not fit a small zip file. The function scans the object and writes a tag or moves it. Objects in the incoming prefix are not readable by CloudFront. Clean objects are copied to the public image prefix. The EICAR test string is the infected sample. A normal small image is the clean sample. Signature updates are part of the function's operational note, because a stale database misses current malware.

## Evidence to collect later

- Bucket settings: Block Public Access, ownership, encryption, policy.
- Presigned upload, download, and expiry.
- A CloudFront URL for a clean object, and a direct S3 URL that is denied.
- Object Lambda result, or the API error plus the thumbnail Lambda that replaced it.
- Lifecycle configuration JSON.
- An inventory report object.
- Scan logs for the clean file and the EICAR file, with the infected object out of the public prefix.

## Not done

No bucket, no function, no scan.
