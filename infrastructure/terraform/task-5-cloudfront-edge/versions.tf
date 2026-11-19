terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.74.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "2.7.0"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = var.local_validate_credentials ? "localvalidateonlykey" : null
  secret_key                  = var.local_validate_credentials ? "local-validate-only" : null
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

variable "local_validate_credentials" {
  type    = bool
  default = true
}

variable "confirm_paid_deployment" {
  type    = bool
  default = false
}

variable "image_bucket_regional_domain" {
  description = "Task 6 bucket regional domain. The placeholder is rejected when the paid gate is on."
  type        = string
  default     = "replace-with-task-6-bucket.s3.ap-south-1.amazonaws.com"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]+\\.s3[.][a-z0-9-]+[.]amazonaws[.]com$", var.image_bucket_regional_domain))
    error_message = "image_bucket_regional_domain must be a regional S3 domain. The viewer cannot choose it."
  }
}

variable "apex_domain" {
  description = "Task 1 apex. This stack rejects it as an image alias and does not create a DNS record."
  type        = string
  default     = "example.invalid"
}

variable "image_aliases" {
  description = "Optional image hostnames such as images.example.com. Empty uses the CloudFront domain and no custom certificate. This stack does not register a domain."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for name in var.image_aliases :
      can(regex("^images[.][a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?([.][a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$", name))
    ])
    error_message = "Every image alias must start with images. and must not be the apex."
  }
}

variable "certificate_arn" {
  description = "ACM certificate ARN in us-east-1 covering the image aliases. Empty is valid only when image_aliases is empty."
  type        = string
  default     = ""

  validation {
    condition     = var.certificate_arn == "" || can(regex("^arn:aws:acm:us-east-1:[0-9]{12}:certificate/[0-9a-f-]+$", var.certificate_arn))
    error_message = "certificate_arn must be an ACM certificate in us-east-1."
  }
}

variable "image_viewer_request_qualified_arn" {
  type        = string
  default     = ""
  description = "Optional check against the version this stack publishes. Empty skips the check. $LATEST is rejected."

  validation {
    condition     = var.image_viewer_request_qualified_arn == "" || can(regex("^arn:aws:lambda:us-east-1:[0-9]{12}:function:[A-Za-z0-9-_]+:[0-9]+$", var.image_viewer_request_qualified_arn))
    error_message = "Lambda@Edge needs a us-east-1 function version ARN. Do not use $LATEST or another region."
  }
}

variable "price_class" {
  type        = string
  default     = "PriceClass_200"
  description = "PriceClass_200 includes Asia, so a Mumbai viewer can use a nearby edge. PriceClass_100 does not."

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be PriceClass_100, PriceClass_200, or PriceClass_All."
  }
}

variable "ipv6_enabled" {
  type    = bool
  default = true
}

variable "max_ttl" {
  type        = number
  default     = 31536000
  description = "Maximum CloudFront TTL in seconds. One year matches an immutable object name."

  validation {
    condition     = var.max_ttl >= 86400 && var.max_ttl <= 31536000
    error_message = "max_ttl must be from 86400 to 31536000 seconds."
  }
}

module "guard" {
  source                  = "../modules/guard"
  confirm_paid_deployment = var.confirm_paid_deployment
}
