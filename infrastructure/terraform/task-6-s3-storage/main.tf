resource "aws_s3_bucket" "images" {
  count  = module.guard.resource_count
  bucket = var.bucket_name
}

resource "aws_s3_bucket_ownership_controls" "images" {
  count  = module.guard.resource_count
  bucket = aws_s3_bucket.images[0].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "images" {
  count                   = module.guard.resource_count
  bucket                  = aws_s3_bucket.images[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "images" {
  count  = module.guard.resource_count
  bucket = aws_s3_bucket.images[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "images" {
  count  = module.guard.resource_count
  bucket = aws_s3_bucket.images[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "images" {
  count  = module.guard.resource_count
  bucket = aws_s3_bucket.images[0].id
  policy = templatefile("${path.module}/../../../security/policies/product-images-bucket-policy.json", {
    bucket_arn       = aws_s3_bucket.images[0].arn
    distribution_arn = "arn:aws:cloudfront::000000000000:distribution/NOT_DEPLOYED"
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "images" {
  count  = module.guard.resource_count
  bucket = aws_s3_bucket.images[0].id

  rule {
    id     = "product-images-tiering"
    status = "Enabled"

    filter {
      prefix = "public/"
    }

    transition {
      days          = 30
      storage_class = "INTELLIGENT_TIERING"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }
}

resource "aws_s3_bucket" "inventory" {
  count  = module.guard.resource_count
  bucket = "${var.bucket_name}-inventory"
}

resource "aws_s3_bucket_public_access_block" "inventory" {
  count                   = module.guard.resource_count
  bucket                  = aws_s3_bucket.inventory[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_inventory" "weekly" {
  count                    = module.guard.resource_count
  bucket                   = aws_s3_bucket.images[0].id
  name                     = "weekly"
  included_object_versions = "Current"

  schedule {
    frequency = "Weekly"
  }

  destination {
    bucket {
      format     = "CSV"
      bucket_arn = aws_s3_bucket.inventory[0].arn
    }
  }
}
