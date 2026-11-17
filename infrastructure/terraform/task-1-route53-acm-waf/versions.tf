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
  description = "Domain you already control. This stack does not register a domain."
  type        = string
  default     = "example.invalid"
}

variable "storefront_cloudfront_domain" {
  description = "Domain name of the Task 5 distribution. Required before an approved apply."
  type        = string
  default     = "storefront.example.invalid"
}

variable "alb_arn" {
  description = "ALB ARN from Task 4. Empty skips the regional WAF association."
  type        = string
  default     = ""
}

module "guard" {
  source                  = "../modules/guard"
  confirm_paid_deployment = var.confirm_paid_deployment
}
