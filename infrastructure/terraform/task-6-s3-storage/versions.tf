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
  description = "Distribution allowed to read public/*. Empty is rejected when the paid gate creates the bucket policy."
}

module "guard" {
  source                  = "../modules/guard"
  confirm_paid_deployment = var.confirm_paid_deployment
}
