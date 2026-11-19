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
      Task    = "3"
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

variable "ecs_ami_id" {
  description = "Replace with the current ECS-optimized AMI before an approved apply."
  type        = string
  default     = "ami-00000000000000000"
}

variable "app_security_group_id" {
  type    = string
  default = "sg-00000000000000000"
}

variable "private_subnet_ids" {
  type    = list(string)
  default = ["subnet-00000000000000001", "subnet-00000000000000002"]

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "Provide at least two private subnets so the group can span Availability Zones."
  }
}

variable "alb_resource_label" {
  description = "app/load-balancer-id/targetgroup-id from the live ALB. Placeholder until deployment."
  type        = string
  default     = "app/cloudcart/targetgroup"
}

variable "expected_schema_version" {
  type    = string
  default = "0"

  validation {
    condition     = length(var.expected_schema_version) > 0 && length(var.expected_schema_version) <= 32 && can(regex("^[A-Za-z0-9._-]+$", var.expected_schema_version))
    error_message = "expected_schema_version must be a short token. It is not a secret."
  }
}

variable "min_size" {
  type        = number
  default     = 2
  description = "Minimum instances. Two keeps one zone alive when the other is gone."

  validation {
    condition     = var.min_size >= 2 && var.min_size <= 4
    error_message = "min_size must be from 2 to 4."
  }
}

variable "max_size" {
  type        = number
  default     = 4
  description = "Ceiling for a short test. Raise it only with a new cost approval."

  validation {
    condition     = var.max_size >= var.min_size && var.max_size <= 6
    error_message = "max_size must be at least min_size and at most 6."
  }
}

variable "desired_capacity" {
  type    = number
  default = 2

  validation {
    condition     = var.desired_capacity >= var.min_size && var.desired_capacity <= var.max_size
    error_message = "desired_capacity must sit between min_size and max_size."
  }
}

variable "on_demand_base_capacity" {
  type        = number
  default     = 1
  description = "On-Demand instances kept even when the rest of the group is Spot."

  validation {
    condition     = var.on_demand_base_capacity >= 1 && var.on_demand_base_capacity <= var.min_size
    error_message = "Keep at least one On-Demand instance, and do not require more On-Demand than min_size."
  }
}

variable "on_demand_percentage_above_base" {
  type        = number
  default     = 0
  description = "Share of capacity above the On-Demand base that is also On-Demand. Zero means that extra capacity is Spot."

  validation {
    condition     = var.on_demand_percentage_above_base >= 0 && var.on_demand_percentage_above_base <= 100
    error_message = "on_demand_percentage_above_base must be from 0 to 100."
  }
}

variable "instance_types" {
  type        = list(string)
  default     = ["t3.small", "t3a.small", "t3.medium"]
  description = "x86 types with at least 2 GiB. A 1 GiB burstable instance cannot hold the 1024 MiB task beside the ECS agent."

  validation {
    condition = length(var.instance_types) >= 2 && alltrue([
      for item in var.instance_types : contains(["t3.small", "t3a.small", "t3.medium", "t3a.medium"], item)
    ])
    error_message = "Use at least two of t3.small, t3a.small, t3.medium, and t3a.medium. Graviton needs a different AMI."
  }
}

variable "cpu_target_percent" {
  type    = number
  default = 60

  validation {
    condition     = var.cpu_target_percent >= 40 && var.cpu_target_percent <= 80
    error_message = "cpu_target_percent must be from 40 to 80 so the group does not flap."
  }
}

variable "request_target_per_instance" {
  type        = number
  default     = 100
  description = "Target ALB requests per target. Both target-tracking policies must agree before the group scales in."

  validation {
    condition     = var.request_target_per_instance >= 20 && var.request_target_per_instance <= 500
    error_message = "request_target_per_instance must be from 20 to 500."
  }
}

module "guard" {
  source                  = "../modules/guard"
  confirm_paid_deployment = var.confirm_paid_deployment
}
