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

variable "vpc_id" {
  type    = string
  default = "vpc-00000000000000000"
}

variable "public_subnet_ids" {
  type    = list(string)
  default = ["subnet-00000000000000011", "subnet-00000000000000012"]
}

variable "private_subnet_ids" {
  type    = list(string)
  default = ["subnet-00000000000000001", "subnet-00000000000000002"]
}

variable "image_uri" {
  description = "ECR image digest. The zero digest is a placeholder and must be replaced before deployment."
  type        = string
  default     = "000000000000.dkr.ecr.ap-south-1.amazonaws.com/cloudcart@sha256:0000000000000000000000000000000000000000000000000000000000000000"
}

variable "db_password_secret_arn" {
  description = "Secrets Manager ARN for the EverShop PostgreSQL password. Not the Task 2 MySQL user."
  type        = string
  default     = "arn:aws:secretsmanager:ap-south-1:000000000000:secret:cloudcart/evershop/postgres"
}

variable "production_listener_arn" {
  description = "HTTPS listener ARN. Replace the placeholder before an approved apply."
  type        = string
  default     = "arn:aws:elasticloadbalancing:ap-south-1:000000000000:listener/app/cloudcart/0000000000000000/0000000000000000"
}

variable "test_listener_arn" {
  description = "Test listener ARN used before production traffic shifts."
  type        = string
  default     = "arn:aws:elasticloadbalancing:ap-south-1:000000000000:listener/app/cloudcart/0000000000000000/0000000000000001"
}

variable "codestar_connection_arn" {
  description = "CodeStar connection created by hand. Empty keeps the pipeline from being planned."
  type        = string
  default     = ""
}

module "guard" {
  source                  = "../modules/guard"
  confirm_paid_deployment = var.confirm_paid_deployment
}
