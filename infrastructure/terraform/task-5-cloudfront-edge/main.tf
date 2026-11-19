resource "aws_cloudfront_origin_access_control" "images" {
  count                             = module.guard.resource_count
  name                              = "cloudcart-images"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_cache_policy" "images" {
  count       = module.guard.resource_count
  name        = "cloudcart-images"
  default_ttl = 86400
  max_ttl     = 604800
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "whitelist"
      headers {
        items = ["Accept"]
      }
    }
    query_strings_config {
      query_string_behavior = "whitelist"
      query_strings {
        items = ["w", "h", "format", "q"]
      }
    }
  }
}

resource "aws_cloudfront_distribution" "storefront" {
  count       = module.guard.resource_count
  enabled     = true
  price_class = "PriceClass_100"
  comment     = "CloudCart storefront and private image origin"

  origin {
    domain_name              = var.image_bucket_regional_domain
    origin_id                = "images"
    origin_access_control_id = aws_cloudfront_origin_access_control.images[0].id
  }

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

  default_cache_behavior {
    target_origin_id       = "alb"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = true
      headers      = ["Host", "Authorization"]
      cookies {
        forward = "all"
      }
    }
  }

  ordered_cache_behavior {
    path_pattern           = "/media/*"
    target_origin_id       = "images"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = aws_cloudfront_cache_policy.images[0].id
    compress               = true

    dynamic "lambda_function_association" {
      for_each = var.image_viewer_request_qualified_arn == "" ? [] : [var.image_viewer_request_qualified_arn]
      content {
        event_type   = "viewer-request"
        lambda_arn   = lambda_function_association.value
        include_body = false
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.certificate_arn == ""
    acm_certificate_arn            = var.certificate_arn == "" ? null : var.certificate_arn
    ssl_support_method             = var.certificate_arn == "" ? null : "sni-only"
    minimum_protocol_version       = "TLSv1.2_2021"
  }
}
