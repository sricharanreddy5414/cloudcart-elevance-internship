resource "aws_s3_bucket" "images" {
  count  = module.guard.resource_count
  bucket = var.bucket_name

  lifecycle {
    prevent_destroy = true
  }
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
    distribution_arn = var.cloudfront_distribution_arn
  })

  lifecycle {
    precondition {
      condition     = can(regex("^arn:aws:cloudfront::[0-9]{12}:distribution/[A-Z0-9]+$", var.cloudfront_distribution_arn)) && !strcontains(var.cloudfront_distribution_arn, "000000000000")
      error_message = "An approved apply needs the Task 5 image distribution ARN. A zero account id or NOT_DEPLOYED value is rejected."
    }
    precondition {
      condition     = !strcontains(var.bucket_name, "-example")
      error_message = "Set bucket_name to the live bucket. The example suffix is rejected."
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "images" {
  count  = module.guard.resource_count
  bucket = aws_s3_bucket.images[0].id

  rule {
    id     = "quarantine-expire"
    status = "Enabled"

    filter {
      prefix = "quarantine/"
    }

    expiration {
      days = var.quarantine_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  rule {
    id     = "rejected-expire"
    status = "Enabled"

    filter {
      prefix = "rejected/"
    }

    expiration {
      days = var.rejected_retention_days
    }
  }

  rule {
    id     = "public-noncurrent-archive"
    status = "Enabled"

    filter {
      prefix = "public/products/"
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "INTELLIGENT_TIERING"
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
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

  optional_fields = ["Size", "LastModifiedDate", "StorageClass", "EncryptionStatus", "ETag"]

  destination {
    bucket {
      format     = "CSV"
      bucket_arn = aws_s3_bucket.inventory[0].arn
      prefix     = "inventory/"
      encryption {
        sse_s3 {}
      }
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "inventory" {
  count  = module.guard.resource_count
  bucket = aws_s3_bucket.inventory[0].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "inventory" {
  count  = module.guard.resource_count
  bucket = aws_s3_bucket.inventory[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "inventory" {
  count  = module.guard.resource_count
  bucket = aws_s3_bucket.inventory[0].id

  rule {
    id     = "expire-inventory-reports"
    status = "Enabled"
    filter {}
    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket_policy" "inventory" {
  count  = module.guard.resource_count
  bucket = aws_s3_bucket.inventory[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.inventory[0].arn,
          "${aws_s3_bucket.inventory[0].arn}/*",
        ]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
      {
        Sid       = "AllowInventoryDelivery"
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.inventory[0].arn}/inventory/*"
        Condition = { ArnLike = { "aws:SourceArn" = aws_s3_bucket.images[0].arn } }
      }
    ]
  })
}

data "archive_file" "scanner" {
  count       = module.guard.resource_count
  type        = "zip"
  output_path = "${path.module}/.build/image-scan.zip"
  source {
    content  = file("${path.module}/../../../security/malware/scan_worker.py")
    filename = "scan_worker.py"
  }
  source {
    content  = file("${path.module}/../../../cloudcart/pipeline.py")
    filename = "cloudcart/pipeline.py"
  }
  source {
    content  = file("${path.module}/../../../cloudcart/s3.py")
    filename = "cloudcart/s3.py"
  }
  source {
    content  = ""
    filename = "cloudcart/__init__.py"
  }
}

resource "aws_sqs_queue" "scan_dlq" {
  count                     = module.guard.resource_count
  name                      = "cloudcart-image-scan-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue" "scan" {
  count                      = module.guard.resource_count
  name                       = "cloudcart-image-scan"
  visibility_timeout_seconds = 180
  message_retention_seconds  = 345600
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.scan_dlq[0].arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue_policy" "scan" {
  count     = module.guard.resource_count
  queue_url = aws_sqs_queue.scan[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowBucketNotification"
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.scan[0].arn
      Condition = { ArnEquals = { "aws:SourceArn" = aws_s3_bucket.images[0].arn } }
    }]
  })
}

resource "aws_s3_bucket_notification" "quarantine" {
  count  = module.guard.resource_count
  bucket = aws_s3_bucket.images[0].id

  queue {
    queue_arn     = aws_sqs_queue.scan[0].arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "quarantine/"
  }

  depends_on = [aws_sqs_queue_policy.scan]
}

resource "aws_dynamodb_table" "uploads" {
  count        = module.guard.resource_count
  name         = "cloudcart-image-uploads"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "upload_id"

  attribute {
    name = "upload_id"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  server_side_encryption {
    enabled = true
  }
}

resource "aws_iam_role" "scanner" {
  count = module.guard.resource_count
  name  = "cloudcart-image-scanner"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "scanner" {
  count  = module.guard.resource_count
  name   = "scanner"
  role   = aws_iam_role.scanner[0].id
  policy = file("${path.module}/../../../security/iam/image-scanner-role-policy.json")
}

resource "aws_cloudwatch_log_group" "scanner" {
  count             = module.guard.resource_count
  name              = "/aws/lambda/cloudcart-image-scan"
  retention_in_days = 7
}

resource "aws_lambda_function" "scanner" {
  count            = module.guard.resource_count
  function_name    = "cloudcart-image-scan"
  description      = "Fail-closed EICAR worker. It cannot promote an object. ClamAV is not in this package."
  role             = aws_iam_role.scanner[0].arn
  runtime          = "python3.12"
  handler          = "scan_worker.handler"
  filename         = data.archive_file.scanner[0].output_path
  source_code_hash = data.archive_file.scanner[0].output_base64sha256
  timeout          = 60
  memory_size      = 512

  environment {
    variables = {
      SCANNER_MODE = "eicar-only"
    }
  }

  depends_on = [aws_cloudwatch_log_group.scanner]
}

resource "aws_lambda_event_source_mapping" "scan" {
  count            = module.guard.resource_count
  event_source_arn = aws_sqs_queue.scan[0].arn
  function_name    = aws_lambda_function.scanner[0].arn
  batch_size       = 1
}

resource "aws_cloudwatch_metric_alarm" "scan_dlq" {
  count               = module.guard.resource_count
  alarm_name          = "cloudcart-image-scan-dlq"
  alarm_description   = "Image scan messages reached the dead-letter queue. No notification topic is attached."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = aws_sqs_queue.scan_dlq[0].name }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
}

output "image_bucket_name" {
  value = one(aws_s3_bucket.images[*].bucket)
}

output "scan_queue_arn" {
  value = one(aws_sqs_queue.scan[*].arn)
}
