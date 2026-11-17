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
  type    = string
  default = "cloudcart-product-images.s3.ap-south-1.amazonaws.com"
}

variable "alb_dns_name" {
  type    = string
  default = "cloudcart.example.invalid"
}

variable "certificate_arn" {
  description = "ACM certificate ARN in us-east-1. Empty uses the default CloudFront certificate and no alias."
  type        = string
  default     = ""
}

module "guard" {
  source                  = "../modules/guard"
  confirm_paid_deployment = var.confirm_paid_deployment
}
