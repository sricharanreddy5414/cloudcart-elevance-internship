resource "aws_route53_zone" "cloudcart" {
  count = module.guard.resource_count
  name  = var.domain_name
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

resource "aws_route53_record" "cloudfront_cert_validation" {
  for_each = var.confirm_paid_deployment ? {
    for option in aws_acm_certificate.cloudfront[0].domain_validation_options : option.domain_name => {
      name  = option.resource_record_name
      type  = option.resource_record_type
      value = option.resource_record_value
    }
  } : {}

  zone_id = aws_route53_zone.cloudcart[0].zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 300
  records = [each.value.value]
}

resource "aws_route53_record" "alb_cert_validation" {
  for_each = var.confirm_paid_deployment ? {
    for option in aws_acm_certificate.alb[0].domain_validation_options : option.domain_name => {
      name  = option.resource_record_name
      type  = option.resource_record_type
      value = option.resource_record_value
    }
  } : {}

  zone_id = aws_route53_zone.cloudcart[0].zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 300
  records = [each.value.value]
}

resource "aws_s3_bucket" "maintenance" {
  count  = module.guard.resource_count
  bucket = "cloudcart-maintenance-${var.domain_name}"
}

resource "aws_s3_bucket_public_access_block" "maintenance" {
  count                   = module.guard.resource_count
  bucket                  = aws_s3_bucket.maintenance[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "maintenance_page" {
  count        = module.guard.resource_count
  bucket       = aws_s3_bucket.maintenance[0].id
  key          = "index.html"
  content_type = "text/html"
  content      = "<!doctype html><title>CloudCart</title><p>CloudCart is temporarily unavailable.</p>"
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
      access_control_max_age_sec = 300
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
    name     = "aws-managed-common"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "cloudcartCommon"
      sampled_requests_enabled   = false
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "cloudcartCloudFront"
    sampled_requests_enabled   = false
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
    name     = "aws-managed-common"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "cloudcartAlbCommon"
      sampled_requests_enabled   = false
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "cloudcartAlb"
    sampled_requests_enabled   = false
  }
}

resource "aws_cloudfront_distribution" "maintenance" {
  count               = module.guard.resource_count
  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  web_acl_id          = aws_wafv2_web_acl.cloudfront[0].arn
  aliases             = ["maintenance.${var.domain_name}"]

  origin {
    domain_name              = aws_s3_bucket.maintenance[0].bucket_regional_domain_name
    origin_id                = "maintenance-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.maintenance[0].id
  }

  default_cache_behavior {
    target_origin_id           = "maintenance-s3"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security[0].id
    compress                   = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cloudfront[0].arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

resource "aws_route53_health_check" "storefront" {
  count             = module.guard.resource_count
  type              = "HTTPS"
  fqdn              = var.storefront_cloudfront_domain
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
    name                   = var.storefront_cloudfront_domain
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = true
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
    name                   = aws_cloudfront_distribution.maintenance[0].domain_name
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_wafv2_web_acl_association" "alb" {
  count        = var.confirm_paid_deployment && var.alb_arn != "" ? 1 : 0
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.alb[0].arn
}
