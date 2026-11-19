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
  region                      = "ap-south-1"
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

variable "bucket_name" {
  type    = string
  default = "cloudcart-product-images-example"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name)) && !strcontains(var.bucket_name, "000000000000")
    error_message = "Bucket name must be a valid S3 name and must not contain a zero account id."
  }
}

variable "cloudfront_distribution_arn" {
  type        = string
  default     = ""
  description = "Task 5 image distribution ARN. Empty is rejected when the paid gate creates the bucket policy. The apex distribution must not be used."

  validation {
    condition     = var.cloudfront_distribution_arn == "" || (can(regex("^arn:aws:cloudfront::[0-9]{12}:distribution/[A-Z0-9]+$", var.cloudfront_distribution_arn)) && !strcontains(var.cloudfront_distribution_arn, "000000000000"))
    error_message = "cloudfront_distribution_arn must be a real CloudFront distribution ARN. A zero account id is rejected."
  }
}

variable "quarantine_retention_days" {
  type    = number
  default = 1

  validation {
    condition     = var.quarantine_retention_days >= 1 && var.quarantine_retention_days <= 7
    error_message = "quarantine_retention_days must be from 1 to 7."
  }
}

variable "rejected_retention_days" {
  type    = number
  default = 7

  validation {
    condition     = var.rejected_retention_days >= 1 && var.rejected_retention_days <= 30
    error_message = "rejected_retention_days must be from 1 to 30."
  }
}

module "guard" {
  source                  = "../modules/guard"
  confirm_paid_deployment = var.confirm_paid_deployment
}
