resource "aws_launch_template" "ecs" {
  count         = module.guard.resource_count
  name_prefix   = "cloudcart-ecs-"
  image_id      = var.ecs_ami_id
  instance_type = "t3.micro"

  vpc_security_group_ids = [var.app_security_group_id]

  iam_instance_profile {
    name = var.instance_profile_name
  }

  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    ECS_CLUSTER             = "cloudcart"
    ASG_NAME                = "cloudcart-ecs"
    EXPECTED_SCHEMA_VERSION = var.expected_schema_version
  }))

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
}

resource "aws_autoscaling_group" "ecs" {
  count                     = module.guard.resource_count
  name                      = "cloudcart-ecs"
  min_size                  = 2
  max_size                  = 4
  desired_capacity          = 2
  vpc_zone_identifier       = var.private_subnet_ids
  health_check_type         = "ELB"
  health_check_grace_period = 300

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 1
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "capacity-optimized"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.ecs[0].id
        version            = "$Latest"
      }

      override {
        instance_type = "t3.micro"
      }

      override {
        instance_type = "t3.small"
      }
    }
  }
}

resource "aws_autoscaling_lifecycle_hook" "warmup" {
  count                  = module.guard.resource_count
  name                   = "cloudcart-warmup"
  autoscaling_group_name = aws_autoscaling_group.ecs[0].name
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_LAUNCHING"
  heartbeat_timeout      = 600
  default_result         = "ABANDON"
}

resource "aws_autoscaling_policy" "cpu" {
  count                  = module.guard.resource_count
  name                   = "cloudcart-cpu"
  autoscaling_group_name = aws_autoscaling_group.ecs[0].name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    target_value = 60

    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }
}

resource "aws_autoscaling_policy" "requests" {
  count                  = module.guard.resource_count
  name                   = "cloudcart-requests"
  autoscaling_group_name = aws_autoscaling_group.ecs[0].name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    target_value = 100

    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = var.alb_resource_label
    }
  }
}
