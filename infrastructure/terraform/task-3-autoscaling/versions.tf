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

variable "ecs_ami_id" {
  description = "Replace with the current ECS-optimized AMI before an approved apply."
  type        = string
  default     = "ami-00000000000000000"
}

variable "instance_profile_name" {
  type    = string
  default = "cloudcart-ecs-instance"
}

variable "app_security_group_id" {
  type    = string
  default = "sg-00000000000000000"
}

variable "private_subnet_ids" {
  type    = list(string)
  default = ["subnet-00000000000000001", "subnet-00000000000000002"]
}

variable "alb_resource_label" {
  description = "app/load-balancer-id/targetgroup-id from the live ALB. Placeholder until deployment."
  type        = string
  default     = "app/cloudcart/targetgroup"
}

variable "expected_schema_version" {
  type    = string
  default = "0"
}

module "guard" {
  source                  = "../modules/guard"
  confirm_paid_deployment = var.confirm_paid_deployment
}
