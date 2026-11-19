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

  default_tags {
    tags = {
      Project = "CloudCart"
      Task    = "2"
    }
  }
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

variable "instance_class" {
  type        = string
  default     = "db.t3.micro"
  description = "RDS instance class. Multi-AZ bills this class twice."

  validation {
    condition     = can(regex("^db\\.[a-z0-9]+\\.[a-z0-9]+$", var.instance_class))
    error_message = "instance_class must look like db.t3.micro."
  }
}

variable "allocated_storage_gb" {
  type        = number
  default     = 20
  description = "Initial gp3 storage in GiB. Twenty is the gp3 minimum."

  validation {
    condition     = var.allocated_storage_gb >= 20 && var.allocated_storage_gb <= 100
    error_message = "allocated_storage_gb must be from 20 to 100."
  }
}

variable "max_allocated_storage_gb" {
  type        = number
  default     = 100
  description = "Storage autoscaling ceiling in GiB. Growth above the initial size is billed."

  validation {
    condition     = var.max_allocated_storage_gb > var.allocated_storage_gb && var.max_allocated_storage_gb <= 200
    error_message = "max_allocated_storage_gb must be larger than allocated_storage_gb and at most 200."
  }
}

variable "backup_retention_days" {
  type        = number
  default     = 7
  description = "Automated backup retention. One day is the minimum that keeps point-in-time recovery."

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be from 1 to 35. Zero disables point-in-time recovery."
  }
}

locals {
  iam_database_user = "cloudcart_iam"
}

module "guard" {
  source                  = "../modules/guard"
  confirm_paid_deployment = var.confirm_paid_deployment
}
