# Task 3 is the ECS container-instance group. It does not create a load balancer,
# a NAT gateway, or a database. Task health stays on the Task 4 target group.
# Instance health is EC2. An ELB health check here would replace instances that
# are not themselves targets.

resource "aws_launch_template" "ecs" {
  count         = module.guard.resource_count
  name_prefix   = "cloudcart-ecs-"
  image_id      = var.ecs_ami_id
  instance_type = var.instance_types[0]

  vpc_security_group_ids = [var.app_security_group_id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs[0].name
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    ECS_CLUSTER             = "cloudcart"
    ASG_NAME                = "cloudcart-ecs"
    EXPECTED_SCHEMA_VERSION = var.expected_schema_version
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "cloudcart-ecs"
    }
  }

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = var.ecs_ami_id != "ami-00000000000000000" && can(regex("^ami-[0-9a-f]{8,17}$", var.ecs_ami_id))
      error_message = "Set ecs_ami_id to the current x86 ECS-optimized AMI. The zero AMI is rejected."
    }

    precondition {
      condition     = var.app_security_group_id != "sg-00000000000000000" && can(regex("^sg-[0-9a-f]{8,17}$", var.app_security_group_id))
      error_message = "Set app_security_group_id to the Task 4 instance security group. Do not open SSH."
    }
  }
}

resource "aws_autoscaling_group" "ecs" {
  count                     = module.guard.resource_count
  name                      = "cloudcart-ecs"
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  vpc_zone_identifier       = var.private_subnet_ids
  health_check_type         = "EC2"
  health_check_grace_period = 300
  capacity_rebalance        = true
  termination_policies      = ["AllocationStrategy"]

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupTerminatingInstances",
  ]

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = var.on_demand_base_capacity
      on_demand_percentage_above_base_capacity = var.on_demand_percentage_above_base
      spot_allocation_strategy                 = "capacity-optimized"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.ecs[0].id
        version            = aws_launch_template.ecs[0].latest_version
      }

      dynamic "override" {
        for_each = var.instance_types
        content {
          instance_type = override.value
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition = length(var.private_subnet_ids) >= 2 && alltrue([
        for id in var.private_subnet_ids : can(regex("^subnet-[0-9a-f]{8,17}$", id)) && !strcontains(id, "000000000000")
      ])
      error_message = "private_subnet_ids must be at least two real private subnets in two Availability Zones."
    }
  }
}

# ABANDON is intentional. CONTINUE on timeout would admit an instance whose
# bootstrap never finished, including one that could not reach the Auto Scaling API.
# The user-data script sends ABANDON itself on a schema or bootstrap failure
# so the group does not wait out the full heartbeat first.
resource "aws_autoscaling_lifecycle_hook" "warmup" {
  count                  = module.guard.resource_count
  name                   = "cloudcart-warmup"
  autoscaling_group_name = aws_autoscaling_group.ecs[0].name
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_LAUNCHING"
  heartbeat_timeout      = 600
  default_result         = "ABANDON"
}

# CONTINUE on a termination timeout so a dead instance is not left in
# Terminating:Wait. The drain script also completes this hook when it can.
resource "aws_autoscaling_lifecycle_hook" "drain" {
  count                  = module.guard.resource_count
  name                   = "cloudcart-drain"
  autoscaling_group_name = aws_autoscaling_group.ecs[0].name
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"
  heartbeat_timeout      = 180
  default_result         = "CONTINUE"
}

resource "aws_autoscaling_policy" "cpu" {
  count                  = module.guard.resource_count
  name                   = "cloudcart-cpu"
  autoscaling_group_name = aws_autoscaling_group.ecs[0].name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    target_value     = var.cpu_target_percent
    disable_scale_in = false

    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }

  estimated_instance_warmup = 300
}

resource "aws_autoscaling_policy" "requests" {
  count                  = module.guard.resource_count
  name                   = "cloudcart-requests"
  autoscaling_group_name = aws_autoscaling_group.ecs[0].name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    target_value     = var.request_target_per_instance
    disable_scale_in = false

    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = var.alb_resource_label
    }
  }

  estimated_instance_warmup = 300

  lifecycle {
    precondition {
      condition     = var.alb_resource_label != "app/cloudcart/targetgroup" && can(regex("^app/.+/.+$", var.alb_resource_label))
      error_message = "Set alb_resource_label to the live app/load-balancer-id/target-group-id value from Task 4."
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "below_minimum" {
  count               = module.guard.resource_count
  alarm_name          = "cloudcart-ecs-below-minimum"
  alarm_description   = "In-service instances fell below the minimum. No notification topic is attached."
  namespace           = "AWS/AutoScaling"
  metric_name         = "GroupInServiceInstances"
  dimensions          = { AutoScalingGroupName = aws_autoscaling_group.ecs[0].name }
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 3
  threshold           = var.min_size
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "notBreaching"
}

data "aws_caller_identity" "current" {
  count = module.guard.resource_count
}

resource "aws_iam_role" "ecs_instance" {
  count = module.guard.resource_count
  name  = "cloudcart-ecs-instance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "ecs" {
  count = module.guard.resource_count
  name  = "cloudcart-ecs-instance"
  role  = aws_iam_role.ecs_instance[0].name
}

resource "aws_iam_role_policy_attachment" "ecs_agent" {
  count      = module.guard.resource_count
  role       = aws_iam_role.ecs_instance[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy" "lifecycle" {
  count = module.guard.resource_count
  name  = "cloudcart-ecs-lifecycle"
  role  = aws_iam_role.ecs_instance[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SchemaVersion"
        Effect   = "Allow"
        Action   = "ssm:GetParameter"
        Resource = "arn:aws:ssm:ap-south-1:${data.aws_caller_identity.current[0].account_id}:parameter/cloudcart/production/schema_version"
      },
      {
        Sid    = "LifecycleHook"
        Effect = "Allow"
        Action = [
          "autoscaling:CompleteLifecycleAction",
          "autoscaling:RecordLifecycleActionHeartbeat",
        ]
        Resource = aws_autoscaling_group.ecs[0].arn
      },
      {
        Sid    = "DrainThisCluster"
        Effect = "Allow"
        Action = [
          "ecs:UpdateContainerInstancesState",
          "ecs:ListContainerInstances",
          "ecs:DescribeContainerInstances",
          "ecs:ListTasks",
          "ecs:DescribeTasks",
        ]
        Resource = [
          "arn:aws:ecs:ap-south-1:${data.aws_caller_identity.current[0].account_id}:cluster/cloudcart",
          "arn:aws:ecs:ap-south-1:${data.aws_caller_identity.current[0].account_id}:container-instance/cloudcart/*",
          "arn:aws:ecs:ap-south-1:${data.aws_caller_identity.current[0].account_id}:task/cloudcart/*",
        ]
      }
    ]
  })
}

output "autoscaling_group_name" {
  value = one(aws_autoscaling_group.ecs[*].name)
}

output "launch_template_id" {
  value = one(aws_launch_template.ecs[*].id)
}

output "instance_profile_name" {
  value = one(aws_iam_instance_profile.ecs[*].name)
}
