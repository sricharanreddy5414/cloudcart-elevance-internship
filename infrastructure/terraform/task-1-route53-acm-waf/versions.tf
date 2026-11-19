terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.74.0"
    }
  }
}

provider "aws" {
  region                      = "ap-south-1"
  access_key                  = var.local_validate_credentials ? "localvalidateonlykey" : null
  secret_key                  = var.local_validate_credentials ? "local-validate-only" : null
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

provider "aws" {
  alias                       = "us_east_1"
  region                      = "us-east-1"
  access_key                  = var.local_validate_credentials ? "localvalidateonlykey" : null
  secret_key                  = var.local_validate_credentials ? "local-validate-only" : null
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

variable "local_validate_credentials" {
  description = "Use inert provider settings for local validation. Set false only for an approved apply."
  type        = bool
  default     = true
}

variable "confirm_paid_deployment" {
  type    = bool
  default = false
}

variable "domain_name" {
  description = "Domain you already control. This stack does not register a domain. example.invalid is rejected when the paid gate is on."
  type        = string
  default     = "example.invalid"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$", var.domain_name))
    error_message = "domain_name must be a lowercase DNS name. This stack does not register a domain."
  }
}

variable "alb_dns_name" {
  description = "Task 4 load balancer DNS name. The placeholder is rejected when the paid gate is on."
  type        = string
  default     = "alb.example.invalid"
}

variable "alb_arn" {
  description = "ALB ARN from Task 4. Empty skips the regional WAF association."
  type        = string
  default     = ""
}

variable "alb_https_listener_arn" {
  description = "Task 4 HTTPS listener ARN. Empty skips attaching the regional certificate."
  type        = string
  default     = ""
}

variable "hsts_max_age_seconds" {
  description = "Short on purpose. Preload is not enabled at any value."
  type        = number
  default     = 300

  validation {
    condition     = var.hsts_max_age_seconds >= 60 && var.hsts_max_age_seconds <= 300
    error_message = "Keep HSTS at or below 300 seconds until the domain is deliberately submitted for preload."
  }
}

variable "waf_rate_limit" {
  description = "Requests per 5 minutes from one IP before the rate rule blocks. Shared NATs can trip this."
  type        = number
  default     = 2000

  validation {
    condition     = var.waf_rate_limit >= 100 && var.waf_rate_limit <= 20000000
    error_message = "WAF rate limits must be between 100 and 20000000."
  }
}

locals {
  maintenance_bucket_name = trim(substr(replace("cloudcart-maint-${replace(var.domain_name, ".", "-")}", "_", "-"), 0, 63), "-")
}

module "guard" {
  source                  = "../modules/guard"
  confirm_paid_deployment = var.confirm_paid_deployment
}
