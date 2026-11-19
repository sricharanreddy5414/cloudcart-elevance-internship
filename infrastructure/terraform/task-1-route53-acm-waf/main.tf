# Task 1 owns the public name, the two certificates, both WAF web ACLs, and one
# CloudFront distribution. The distribution is the only owner of the apex alias.
# A second distribution cannot hold the same alias, so maintenance is an origin
# group on this distribution, not a second hostname. Route 53 still has primary
# and secondary failover records. Both alias this distribution: a second
# CloudFront name would present a certificate that does not match the apex.
# This stack does not register a domain and does not create a load balancer.

resource "aws_route53_zone" "cloudcart" {
  count = module.guard.resource_count
  name  = var.domain_name

  lifecycle {
    precondition {
      condition     = var.domain_name != "example.invalid"
      error_message = "Set domain_name to a name you already control. example.invalid is the local placeholder. This stack does not register a domain."
    }
  }
}

resource "aws_acm_certificate" "cloudfront" {
  count                     = module.guard.resource_count
  provider                  = aws.us_east_1
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate" "alb" {
  count                     = module.guard.resource_count
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = var.confirm_paid_deployment ? {
    for option in concat(
      aws_acm_certificate.cloudfront[0].domain_validation_options,
      aws_acm_certificate.alb[0].domain_validation_options,
    ) : option.resource_record_name => option.resource_record_value
  } : {}

  zone_id         = aws_route53_zone.cloudcart[0].zone_id
  name            = each.key
  type            = "CNAME"
  ttl             = 300
  records         = [each.value]
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "cloudfront" {
  count                   = module.guard.resource_count
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cloudfront[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  lifecycle {
    precondition {
      condition = length(distinct([
        for option in concat(
          aws_acm_certificate.cloudfront[0].domain_validation_options,
          aws_acm_certificate.alb[0].domain_validation_options,
        ) : option.resource_record_name
        ])) == length(distinct([
        for option in concat(
          aws_acm_certificate.cloudfront[0].domain_validation_options,
          aws_acm_certificate.alb[0].domain_validation_options,
        ) : "${option.resource_record_name}=${option.resource_record_value}"
      ]))
      error_message = "The two certificates disagree on a DNS validation value. Stop and create the records manually. This stack will not overwrite one value with the other."
    }
  }
}

resource "aws_acm_certificate_validation" "alb" {
  count                   = module.guard.resource_count
  certificate_arn         = aws_acm_certificate.alb[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

resource "aws_s3_bucket" "maintenance" {
  count         = module.guard.resource_count
  bucket        = local.maintenance_bucket_name
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "maintenance" {
  count                   = module.guard.resource_count
  bucket                  = aws_s3_bucket.maintenance[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "maintenance" {
  count  = module.guard.resource_count
  bucket = aws_s3_bucket.maintenance[0].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "maintenance" {
  count  = module.guard.resource_count
  bucket = aws_s3_bucket.maintenance[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "maintenance_page" {
  count        = module.guard.resource_count
  bucket       = aws_s3_bucket.maintenance[0].id
  key          = "index.html"
  content_type = "text/html"
  content      = "<!doctype html><title>CloudCart</title><p>CloudCart is temporarily unavailable.</p>"

  depends_on = [
    aws_s3_bucket_public_access_block.maintenance,
    aws_s3_bucket_server_side_encryption_configuration.maintenance,
  ]
}

resource "aws_cloudfront_origin_request_policy" "store" {
  count   = module.guard.resource_count
  name    = "cloudcart-store-origin"
  comment = "Cookies and query strings reach the app. Host and Authorization stay off the request so S3 origin access control can sign the maintenance failover."

  cookies_config {
    cookie_behavior = "all"
  }

  headers_config {
    header_behavior = "whitelist"
    headers {
      items = ["accept", "accept-language", "origin", "referer", "user-agent"]
    }
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}

resource "aws_cloudfront_origin_access_control" "maintenance" {
  count                             = module.guard.resource_count
  name                              = "cloudcart-maintenance"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_response_headers_policy" "security" {
  count = module.guard.resource_count
  name  = "cloudcart-security-headers"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = var.hsts_max_age_seconds
      include_subdomains         = true
      override                   = true
      preload                    = false
    }
  }
}

resource "aws_wafv2_web_acl" "cloudfront" {
  count    = module.guard.resource_count
  provider = aws.us_east_1
  name     = "cloudcart-cloudfront"
  scope    = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "ip-rate-limit"
    priority = 0

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "cloudcartCloudFrontRate"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-managed-common"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        rule_action_override {
          name = "SizeRestrictions_BODY"
          action_to_use {
            count {}
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "cloudcartCommon"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "cloudcartCloudFront"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl" "alb" {
  count = module.guard.resource_count
  name  = "cloudcart-alb"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "ip-rate-limit"
    priority = 0

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "cloudcartAlbRate"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-managed-common"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        rule_action_override {
          name = "SizeRestrictions_BODY"
          action_to_use {
            count {}
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "cloudcartAlbCommon"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "cloudcartAlb"
    sampled_requests_enabled   = true
  }
}

resource "aws_cloudfront_distribution" "edge" {
  count               = module.guard.resource_count
  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_200"
  is_ipv6_enabled     = true
  web_acl_id          = aws_wafv2_web_acl.cloudfront[0].arn
  aliases             = [var.domain_name]
  comment             = "CloudCart public entry. Origin failover serves the private maintenance page."

  origin {
    domain_name = var.alb_dns_name
    origin_id   = "alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  origin {
    domain_name              = aws_s3_bucket.maintenance[0].bucket_regional_domain_name
    origin_id                = "maintenance-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.maintenance[0].id
  }

  origin_group {
    origin_id = "storefront-with-maintenance"

    failover_criteria {
      status_codes = [500, 502, 503, 504]
    }

    member {
      origin_id = "alb"
    }

    member {
      origin_id = "maintenance-s3"
    }
  }

  default_cache_behavior {
    target_origin_id           = "storefront-with-maintenance"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.store[0].id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security[0].id
    compress                   = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cloudfront[0].certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  lifecycle {
    precondition {
      condition     = var.alb_dns_name != "alb.example.invalid" && !strcontains(var.alb_dns_name, "000000000000")
      error_message = "Set alb_dns_name to the Task 4 load balancer DNS name before an approved apply."
    }
  }
}

resource "aws_s3_bucket_policy" "maintenance" {
  count  = module.guard.resource_count
  bucket = aws_s3_bucket.maintenance[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.maintenance[0].arn,
          "${aws_s3_bucket.maintenance[0].arn}/*",
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
      {
        Sid       = "AllowCloudFrontRead"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.maintenance[0].arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.edge[0].arn
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.maintenance]
}

resource "aws_route53_health_check" "storefront" {
  count             = module.guard.resource_count
  type              = "HTTPS"
  fqdn              = aws_cloudfront_distribution.edge[0].domain_name
  port              = 443
  resource_path     = "/"
  request_interval  = 30
  failure_threshold = 3
}

resource "aws_route53_record" "primary" {
  count           = module.guard.resource_count
  zone_id         = aws_route53_zone.cloudcart[0].zone_id
  name            = var.domain_name
  type            = "A"
  set_identifier  = "primary"
  health_check_id = aws_route53_health_check.storefront[0].id

  failover_routing_policy {
    type = "PRIMARY"
  }

  alias {
    name                   = aws_cloudfront_distribution.edge[0].domain_name
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "secondary" {
  count          = module.guard.resource_count
  zone_id        = aws_route53_zone.cloudcart[0].zone_id
  name           = var.domain_name
  type           = "A"
  set_identifier = "secondary"

  failover_routing_policy {
    type = "SECONDARY"
  }

  alias {
    name                   = aws_cloudfront_distribution.edge[0].domain_name
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "primary_ipv6" {
  count           = module.guard.resource_count
  zone_id         = aws_route53_zone.cloudcart[0].zone_id
  name            = var.domain_name
  type            = "AAAA"
  set_identifier  = "primary-ipv6"
  health_check_id = aws_route53_health_check.storefront[0].id

  failover_routing_policy {
    type = "PRIMARY"
  }

  alias {
    name                   = aws_cloudfront_distribution.edge[0].domain_name
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "secondary_ipv6" {
  count          = module.guard.resource_count
  zone_id        = aws_route53_zone.cloudcart[0].zone_id
  name           = var.domain_name
  type           = "AAAA"
  set_identifier = "secondary-ipv6"

  failover_routing_policy {
    type = "SECONDARY"
  }

  alias {
    name                   = aws_cloudfront_distribution.edge[0].domain_name
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_wafv2_web_acl_association" "alb" {
  count        = var.confirm_paid_deployment && var.alb_arn != "" ? 1 : 0
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.alb[0].arn

  lifecycle {
    precondition {
      condition     = !strcontains(var.alb_arn, "000000000000")
      error_message = "alb_arn must be the Task 4 load balancer ARN. A zero account id is rejected."
    }
  }
}

resource "aws_lb_listener_certificate" "alb" {
  count           = var.confirm_paid_deployment && var.alb_https_listener_arn != "" ? 1 : 0
  listener_arn    = var.alb_https_listener_arn
  certificate_arn = aws_acm_certificate_validation.alb[0].certificate_arn

  lifecycle {
    precondition {
      condition     = !strcontains(var.alb_https_listener_arn, "000000000000")
      error_message = "alb_https_listener_arn must be the Task 4 HTTPS listener. A zero account id is rejected."
    }
  }
}

output "cloudfront_certificate_arn" {
  value = one(aws_acm_certificate_validation.cloudfront[*].certificate_arn)
}

output "alb_certificate_arn" {
  value = one(aws_acm_certificate_validation.alb[*].certificate_arn)
}

output "distribution_domain_name" {
  value = one(aws_cloudfront_distribution.edge[*].domain_name)
}

output "name_servers" {
  value = one(aws_route53_zone.cloudcart[*].name_servers)
}
