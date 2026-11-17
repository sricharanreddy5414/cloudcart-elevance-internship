# S3 Object Lambda feasibility

Checked against AWS documentation on 17 November 2026.

Source: [Amazon S3 Object Lambda availability change](https://docs.aws.amazon.com/AmazonS3/latest/userguide/amazons3-ol-change.html).

As of 7 November 2025, S3 Object Lambda is available only to customers who were already using it, and to selected partners. New customers cannot start using it. This account has not been asked to create an Object Lambda access point, so eligibility is not proven either way. The API was not called, because that would be an AWS create attempt.

The assigned requirement is preserved: on-demand thumbnails through S3 Object Lambda, if the account is eligible.

The implementation that exists in this repository is different. A clean upload is resized with Pillow and written to `thumbnails/` as an ordinary object. That path is covered by `tests/unit/test_images_and_presign.py`. It is not Object Lambda, and the test report does not call it Object Lambda.

If an approved account call later returns an access error, that error becomes the feasibility evidence and this thumbnail path remains the alternative. If the call succeeds, an Object Lambda access point can be added without changing the bucket that stores the originals.
