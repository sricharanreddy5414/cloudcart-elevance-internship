resource "aws_cloudfront_origin_access_control" "images" {
  count                             = module.guard.resource_count
  name                              = "cloudcart-images"
  description                       = "SigV4 access from the image distribution to the private Task 6 bucket."
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_cache_policy" "images" {
  count       = module.guard.resource_count
  name        = "cloudcart-images"
  comment     = "Path-only cache key. Cookies, request headers, and query strings are excluded so a viewer cannot split or poison the cache."
  default_ttl = 86400
  max_ttl     = var.max_ttl
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
  }
}

resource "aws_cloudfront_origin_request_policy" "images" {
  count   = module.guard.resource_count
  name    = "cloudcart-images-origin"
  comment = "S3 does not receive cookies, headers, or query strings. The object key is the cache key."

  cookies_config {
    cookie_behavior = "none"
  }
  headers_config {
    header_behavior = "none"
  }
  query_strings_config {
    query_string_behavior = "none"
  }
}

resource "aws_cloudfront_response_headers_policy" "images" {
  count   = module.guard.resource_count
  name    = "cloudcart-images-security"
  comment = "Short HSTS, no preload, matching the Task 1 storefront choice."

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 300
      include_subdomains         = true
      override                   = true
      preload                    = false
    }
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "no-referrer"
      override        = true
    }
  }
}

resource "aws_s3_bucket" "logs" {
  count         = module.guard.resource_count
  bucket_prefix = "cloudcart-image-logs-"
  force_destroy = false
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  count  = module.guard.resource_count
  bucket = aws_s3_bucket.logs[0].id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  count                   = module.guard.resource_count
  bucket                  = aws_s3_bucket.logs[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  count  = module.guard.resource_count
  bucket = aws_s3_bucket.logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  count  = module.guard.resource_count
  bucket = aws_s3_bucket.logs[0].id

  rule {
    id     = "expire-image-access-logs"
    status = "Enabled"
    filter {}
    expiration {
      days = 14
    }
  }
}

resource "aws_s3_bucket_policy" "logs" {
  count  = module.guard.resource_count
  bucket = aws_s3_bucket.logs[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource = [
        aws_s3_bucket.logs[0].arn,
        "${aws_s3_bucket.logs[0].arn}/*",
      ]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}

data "aws_canonical_user_id" "current" {
  count = module.guard.resource_count
}

resource "aws_s3_bucket_acl" "logs" {
  count  = module.guard.resource_count
  bucket = aws_s3_bucket.logs[0].id

  access_control_policy {
    grant {
      grantee {
        id   = data.aws_canonical_user_id.current[0].id
        type = "CanonicalUser"
      }
      permission = "FULL_CONTROL"
    }
    grant {
      grantee {
        # AWS CloudFront standard-log delivery account. This is not an account secret.
        id   = "c4c1ede66af53448b93c283ce9448c4ba468c9432aa01d700d3878632f77d2d0"
        type = "CanonicalUser"
      }
      permission = "FULL_CONTROL"
    }
    owner {
      id = data.aws_canonical_user_id.current[0].id
    }
  }

  depends_on = [
    aws_s3_bucket_ownership_controls.logs,
    aws_s3_bucket_public_access_block.logs,
  ]
}

data "archive_file" "image_request" {
  count       = module.guard.resource_count
  type        = "zip"
  source_file = "${path.module}/../../../application/edge-functions/image-request.js"
  output_path = "${path.module}/.build/image-request.zip"
}

data "archive_file" "image_cache" {
  count       = module.guard.resource_count
  type        = "zip"
  source_file = "${path.module}/../../../application/edge-functions/cache-headers.js"
  output_path = "${path.module}/.build/image-cache.zip"
}

resource "aws_iam_role" "edge" {
  count = module.guard.resource_count
  name  = "cloudcart-image-edge"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"] }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "edge" {
  count  = module.guard.resource_count
  name   = "edge-logs"
  role   = aws_iam_role.edge[0].id
  policy = file("${path.module}/../../../security/iam/image-edge-role-policy.json")
}

resource "aws_lambda_function" "image_request" {
  count            = module.guard.resource_count
  function_name    = "cloudcart-image-request"
  description      = "Validates product-image paths. Published in us-east-1 for Lambda@Edge."
  role             = aws_iam_role.edge[0].arn
  runtime          = "nodejs20.x"
  handler          = "image-request.handler"
  filename         = data.archive_file.image_request[0].output_path
  source_code_hash = data.archive_file.image_request[0].output_base64sha256
  publish          = true
  timeout          = 5
  memory_size      = 128
}

resource "aws_lambda_function" "image_cache" {
  count            = module.guard.resource_count
  function_name    = "cloudcart-image-cache"
  description      = "Sets Cache-Control on image responses. Published in us-east-1 for Lambda@Edge."
  role             = aws_iam_role.edge[0].arn
  runtime          = "nodejs20.x"
  handler          = "cache-headers.handler"
  filename         = data.archive_file.image_cache[0].output_path
  source_code_hash = data.archive_file.image_cache[0].output_base64sha256
  publish          = true
  timeout          = 5
  memory_size      = 128
}

resource "aws_lambda_permission" "image_request" {
  count         = module.guard.resource_count
  statement_id  = "AllowEdgeReplication"
  action        = "lambda:GetFunction"
  function_name = aws_lambda_function.image_request[0].function_name
  principal     = "edgelambda.amazonaws.com"
  qualifier     = aws_lambda_function.image_request[0].version
}

resource "aws_lambda_permission" "image_cache" {
  count         = module.guard.resource_count
  statement_id  = "AllowEdgeReplication"
  action        = "lambda:GetFunction"
  function_name = aws_lambda_function.image_cache[0].function_name
  principal     = "edgelambda.amazonaws.com"
  qualifier     = aws_lambda_function.image_cache[0].version
}

resource "aws_cloudfront_distribution" "images" {
  count           = module.guard.resource_count
  enabled         = true
  is_ipv6_enabled = var.ipv6_enabled
  http_version    = "http2and3"
  price_class     = var.price_class
  comment         = "CloudCart product images. This distribution does not own the Task 1 apex alias."
  aliases         = var.image_aliases

  origin {
    domain_name              = var.image_bucket_regional_domain
    origin_id                = "images"
    origin_access_control_id = aws_cloudfront_origin_access_control.images[0].id
  }

  default_cache_behavior {
    target_origin_id           = "images"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = aws_cloudfront_cache_policy.images[0].id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.images[0].id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.images[0].id

    lambda_function_association {
      event_type   = "viewer-request"
      lambda_arn   = aws_lambda_function.image_request[0].qualified_arn
      include_body = false
    }

    lambda_function_association {
      event_type   = "viewer-response"
      lambda_arn   = aws_lambda_function.image_cache[0].qualified_arn
      include_body = false
    }
  }

  custom_error_response {
    error_code            = 403
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    error_caching_min_ttl = 10
  }

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.logs[0].bucket_domain_name
    prefix          = "images/"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = length(var.image_aliases) == 0
    acm_certificate_arn            = length(var.image_aliases) == 0 ? null : var.certificate_arn
    ssl_support_method             = length(var.image_aliases) == 0 ? null : "sni-only"
    minimum_protocol_version       = length(var.image_aliases) == 0 ? null : "TLSv1.2_2021"
  }

  lifecycle {
    precondition {
      condition     = length(setintersection(var.image_aliases, [var.apex_domain, "www.${var.apex_domain}"])) == 0
      error_message = "Image aliases must not include the Task 1 apex or its www name."
    }
    precondition {
      condition     = length(var.image_aliases) == 0 || (can(regex("^arn:aws:acm:us-east-1:[0-9]{12}:certificate/", var.certificate_arn)) && !strcontains(var.certificate_arn, "000000000000"))
      error_message = "A custom image hostname needs an ACM certificate in us-east-1. A zero account id is rejected."
    }
    precondition {
      condition     = !strcontains(var.image_bucket_regional_domain, "000000000000") && !strcontains(var.image_bucket_regional_domain, "example.invalid") && var.image_bucket_regional_domain != "replace-with-task-6-bucket.s3.ap-south-1.amazonaws.com"
      error_message = "Set image_bucket_regional_domain to the Task 6 bucket. The placeholder is rejected."
    }
    precondition {
      condition     = var.image_viewer_request_qualified_arn == "" || var.image_viewer_request_qualified_arn == aws_lambda_function.image_request[0].qualified_arn
      error_message = "image_viewer_request_qualified_arn must be empty or the version this stack publishes. Do not attach $LATEST or another region."
    }
  }

  depends_on = [
    aws_s3_bucket_acl.logs,
    aws_lambda_permission.image_request,
    aws_lambda_permission.image_cache,
  ]
}

resource "aws_cloudwatch_metric_alarm" "image_5xx" {
  count               = module.guard.resource_count
  alarm_name          = "cloudcart-images-5xx"
  alarm_description   = "Image distribution 5xx rate stayed above 5 percent. No notification topic is attached."
  namespace           = "AWS/CloudFront"
  metric_name         = "5xxErrorRate"
  dimensions          = { DistributionId = aws_cloudfront_distribution.images[0].id, Region = "Global" }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "image_4xx" {
  count               = module.guard.resource_count
  alarm_name          = "cloudcart-images-4xx"
  alarm_description   = "Image distribution 4xx rate stayed above 50 percent. Rejected paths are 4xx, so this threshold is high. No notification topic is attached."
  namespace           = "AWS/CloudFront"
  metric_name         = "4xxErrorRate"
  dimensions          = { DistributionId = aws_cloudfront_distribution.images[0].id, Region = "Global" }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 50
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
}

output "image_distribution_arn" {
  description = "Pass this to Task 6 as cloudfront_distribution_arn. Do not pass the Task 1 apex distribution."
  value       = one(aws_cloudfront_distribution.images[*].arn)
}

output "image_distribution_domain" {
  description = "CloudFront domain for the image distribution. A custom hostname is not created here."
  value       = one(aws_cloudfront_distribution.images[*].domain_name)
}

output "image_request_version_arn" {
  value = one(aws_lambda_function.image_request[*].qualified_arn)
}
