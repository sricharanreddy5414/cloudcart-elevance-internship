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

variable "enable_interface_endpoints" {
  type        = bool
  default     = true
  description = "Create STS and Secrets Manager interface endpoints when the paid gate is also true. An interface endpoint is about USD 0.01 per Availability Zone-hour plus data. Two endpoints in two zones is about USD 0.04 per hour before GST. Verify the current ap-south-1 price before apply. This variable does not create anything while confirm_paid_deployment is false."
}

module "guard" {
  source                  = "../modules/guard"
  confirm_paid_deployment = var.confirm_paid_deployment
}
