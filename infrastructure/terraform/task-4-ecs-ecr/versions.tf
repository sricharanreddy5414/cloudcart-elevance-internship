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
  region                      = var.aws_region
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

variable "aws_region" {
  type    = string
  default = "ap-south-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "Region must look like ap-south-1."
  }
}

variable "artifact_bucket_name" {
  type        = string
  default     = null
  description = "Globally unique pipeline artifact bucket. Null uses cloudcart-pipeline plus the caller account id and region when local_validate_credentials is false. No account id is hardcoded."

  validation {
    condition = (
      var.artifact_bucket_name == null && !strcontains(coalesce(var.artifact_bucket_name, "cloudcart-pipeline"), "000000000000")
      ) || (
      can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", coalesce(var.artifact_bucket_name, "cloudcart")))
      && !strcontains(coalesce(var.artifact_bucket_name, "cloudcart"), "000000000000")
      && !can(regex("^[0-9]{1,3}(\\.[0-9]{1,3}){3}$", coalesce(var.artifact_bucket_name, "cloudcart")))
    )
    error_message = "Bucket name must be a valid S3 name and must not be the retired zero-account placeholder or an IP address."
  }
}

variable "vpc_cidr" {
  type        = string
  default     = ""
  description = "VPC CIDR. When set, task DNS egress is the Amazon resolver at that CIDR base plus two. Empty keeps DNS egress at 0.0.0.0/0 rather than guessing a private range."

  validation {
    condition     = var.vpc_cidr == "" || can(cidrhost(var.vpc_cidr, 2))
    error_message = "vpc_cidr must be empty or a valid IPv4 CIDR."
  }
}

variable "database_security_group_id" {
  type        = string
  default     = ""
  description = "EverShop PostgreSQL security group. Empty omits the 5432 egress rule instead of opening that port to the internet."

  validation {
    condition     = var.database_security_group_id == "" || can(regex("^sg-[0-9a-f]{8,17}$", var.database_security_group_id))
    error_message = "database_security_group_id must be empty or an sg- id."
  }
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
