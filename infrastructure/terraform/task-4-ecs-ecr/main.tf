resource "aws_ecr_repository" "app" {
  count                = module.guard.resource_count
  name                 = "cloudcart"
  image_tag_mutability = "IMMUTABLE"

  lifecycle {
    prevent_destroy = true
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecs_cluster" "this" {
  count = module.guard.resource_count
  name  = "cloudcart"
}

resource "aws_cloudwatch_log_group" "app" {
  count             = module.guard.resource_count
  name              = "/cloudcart/evershop"
  retention_in_days = 7
}

resource "aws_iam_role" "execution" {
  count = module.guard.resource_count
  name  = "cloudcart-ecs-execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role" "task" {
  count = module.guard.resource_count
  name  = "cloudcart-ecs-task"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "execution" {
  count  = module.guard.resource_count
  name   = "execution"
  role   = aws_iam_role.execution[0].id
  policy = file("${path.module}/../../../security/iam/execution-role-policy.json")
}

resource "aws_iam_role_policy" "task" {
  count  = module.guard.resource_count
  name   = "task"
  role   = aws_iam_role.task[0].id
  policy = file("${path.module}/../../../security/iam/task-role-policy.json")
}

resource "aws_security_group" "alb" {
  count       = module.guard.resource_count
  name        = "cloudcart-alb"
  description = "Public HTTP and HTTPS. Egress is only TCP 3000 to the task security group."
  vpc_id      = var.vpc_id
}

resource "aws_security_group" "tasks" {
  count       = module.guard.resource_count
  name        = "cloudcart-tasks"
  description = "EverShop tasks. Ingress is only the load balancer on port 3000."
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  count             = module.guard.resource_count
  security_group_id = aws_security_group.alb[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  description       = "Public HTTP redirect"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  count             = module.guard.resource_count
  security_group_id = aws_security_group.alb[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "Public HTTPS"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_tasks" {
  count                        = module.guard.resource_count
  security_group_id            = aws_security_group.alb[0].id
  referenced_security_group_id = aws_security_group.tasks[0].id
  ip_protocol                  = "tcp"
  from_port                    = 3000
  to_port                      = 3000
  description                  = "Health checks and EverShop traffic"
}

resource "aws_vpc_security_group_ingress_rule" "tasks_from_alb" {
  count                        = module.guard.resource_count
  security_group_id            = aws_security_group.tasks[0].id
  referenced_security_group_id = aws_security_group.alb[0].id
  ip_protocol                  = "tcp"
  from_port                    = 3000
  to_port                      = 3000
  description                  = "EverShop and target health checks from the load balancer"
}

resource "aws_vpc_security_group_egress_rule" "tasks_https" {
  count             = module.guard.resource_count
  security_group_id = aws_security_group.tasks[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS to ECR, Logs, SSM, Secrets Manager, and STS. This stack does not own interface endpoints, so the destination cannot yet be a security group."
}

resource "aws_vpc_security_group_egress_rule" "tasks_dns" {
  count             = module.guard.resource_count
  security_group_id = aws_security_group.tasks[0].id
  cidr_ipv4         = local.task_dns_cidr
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
  description       = "DNS. Uses the VPC resolver only when vpc_cidr is set. Otherwise this remains 0.0.0.0/0 because the VPC CIDR is not known."
}

resource "aws_vpc_security_group_egress_rule" "tasks_dns_tcp" {
  count             = module.guard.resource_count
  security_group_id = aws_security_group.tasks[0].id
  cidr_ipv4         = local.task_dns_cidr
  ip_protocol       = "tcp"
  from_port         = 53
  to_port           = 53
  description       = "DNS over TCP."
}

resource "aws_vpc_security_group_egress_rule" "tasks_to_postgres" {
  count                        = module.guard.resource_count * (var.database_security_group_id == "" ? 0 : 1)
  security_group_id            = aws_security_group.tasks[0].id
  referenced_security_group_id = var.database_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "EverShop PostgreSQL. This is not the Task 2 MySQL security group."
}

resource "aws_lb" "app" {
  count              = module.guard.resource_count
  name               = "cloudcart"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb[0].id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_target_group" "blue" {
  count       = module.guard.resource_count
  name        = "cloudcart-blue"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  deregistration_delay = 30
}

resource "aws_lb_target_group" "green" {
  count       = module.guard.resource_count
  name        = "cloudcart-green"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  count             = module.guard.resource_count
  load_balancer_arn = aws_lb.app[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_ecs_task_definition" "app" {
  count                    = module.guard.resource_count
  family                   = "cloudcart-evershop"
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.execution[0].arn
  task_role_arn            = aws_iam_role.task[0].arn

  container_definitions = jsonencode([{
    name      = "evershop"
    image     = var.image_uri
    essential = true
    portMappings = [{
      containerPort = 3000
      protocol      = "tcp"
    }]
    environment = [
      { name = "NODE_ENV", value = "production" },
      { name = "DB_PORT", value = "5432" },
      { name = "DB_NAME", value = "postgres" },
      { name = "DB_USER", value = "postgres" },
    ]
    secrets = [{
      name      = "DB_PASSWORD"
      valueFrom = var.db_password_secret_arn
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.app[0].name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "evershop"
      }
    }
  }])

  lifecycle {
    precondition {
      condition     = !strcontains(var.image_uri, "000000000000")
      error_message = "Replace image_uri with the real ECR digest before an approved apply."
    }
  }
}

resource "aws_ecs_service" "app" {
  count           = module.guard.resource_count
  name            = "evershop"
  cluster         = aws_ecs_cluster.this[0].id
  task_definition = aws_ecs_task_definition.app[0].arn
  desired_count   = 2
  launch_type     = "EC2"

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.tasks[0].id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.blue[0].arn
    container_name   = "evershop"
    container_port   = 3000
  }

  lifecycle {
    ignore_changes = [task_definition, load_balancer]
  }
}

resource "aws_iam_role" "codedeploy" {
  count = module.guard.resource_count
  name  = "cloudcart-codedeploy"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codedeploy.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy" {
  count      = module.guard.resource_count
  role       = aws_iam_role.codedeploy[0].name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

resource "aws_codedeploy_app" "ecs" {
  count            = module.guard.resource_count
  name             = "cloudcart"
  compute_platform = "ECS"
}

resource "aws_codedeploy_deployment_group" "ecs" {
  count                  = module.guard.resource_count
  app_name               = aws_codedeploy_app.ecs[0].name
  deployment_group_name  = "cloudcart"
  service_role_arn       = aws_iam_role.codedeploy[0].arn
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "STOP_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.this[0].name
    service_name = aws_ecs_service.app[0].name
  }

  lifecycle {
    precondition {
      condition     = !strcontains(var.production_listener_arn, "000000000000") && !strcontains(var.test_listener_arn, "000000000000")
      error_message = "Replace the listener ARNs before an approved apply. The zero account id is rejected."
    }
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [var.production_listener_arn]
      }

      test_traffic_route {
        listener_arns = [var.test_listener_arn]
      }

      target_group {
        name = aws_lb_target_group.blue[0].name
      }

      target_group {
        name = aws_lb_target_group.green[0].name
      }
    }
  }
}

resource "aws_ssm_parameter" "db_host" {
  count = module.guard.resource_count
  name  = "/cloudcart/production/db_host"
  type  = "String"
  value = "replace-with-postgresql-endpoint"
}

resource "aws_ssm_parameter" "image_bucket" {
  count = module.guard.resource_count
  name  = "/cloudcart/production/image_bucket"
  type  = "String"
  value = "replace-with-product-image-bucket"
}

resource "aws_iam_role" "codebuild" {
  count = module.guard.resource_count
  name  = "cloudcart-codebuild"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codebuild" {
  count = module.guard.resource_count
  name  = "codebuild"
  role  = aws_iam_role.codebuild[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:*:log-group:/aws/codebuild/cloudcart",
          "arn:aws:logs:${var.aws_region}:*:log-group:/aws/codebuild/cloudcart:*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:StartImageScan"
        ]
        Resource = aws_ecr_repository.app[0].arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:AbortMultipartUpload",
        ]
        Resource = "${aws_s3_bucket.pipeline_artifacts[0].arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketVersioning", "s3:GetBucketLocation"]
        Resource = aws_s3_bucket.pipeline_artifacts[0].arn
      }
    ]
  })
}

data "aws_caller_identity" "current" {
  count = var.local_validate_credentials ? 0 : 1
}

locals {
  generated_artifact_bucket_name = var.local_validate_credentials ? null : format(
    "cloudcart-pipeline-%s-%s",
    data.aws_caller_identity.current[0].account_id,
    var.aws_region,
  )
  artifact_bucket_name = coalesce(
    var.artifact_bucket_name,
    local.generated_artifact_bucket_name,
    "cloudcart-pipeline-not-created",
  )
  task_dns_cidr = var.vpc_cidr == "" ? "0.0.0.0/0" : "${cidrhost(var.vpc_cidr, 2)}/32"
}

resource "aws_s3_bucket" "pipeline_artifacts" {
  count         = module.guard.resource_count
  bucket        = local.artifact_bucket_name
  force_destroy = false

  lifecycle {
    prevent_destroy = true

    precondition {
      condition = (
        var.artifact_bucket_name == null && !var.local_validate_credentials && local.generated_artifact_bucket_name != null
        ) || (
        var.artifact_bucket_name != null && !strcontains(coalesce(var.artifact_bucket_name, "cloudcart"), "000000000000")
      )
      error_message = "An approved apply needs artifact_bucket_name or real credentials so the name can include the account id. The 000000000000 placeholder is rejected."
    }
  }
}

resource "aws_s3_bucket_public_access_block" "pipeline_artifacts" {
  count                   = module.guard.resource_count
  bucket                  = aws_s3_bucket.pipeline_artifacts[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "pipeline_artifacts" {
  count  = module.guard.resource_count
  bucket = aws_s3_bucket.pipeline_artifacts[0].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "pipeline_artifacts" {
  count  = module.guard.resource_count
  bucket = aws_s3_bucket.pipeline_artifacts[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline_artifacts" {
  count  = module.guard.resource_count
  bucket = aws_s3_bucket.pipeline_artifacts[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "pipeline_artifacts" {
  count  = module.guard.resource_count
  bucket = aws_s3_bucket.pipeline_artifacts[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource = [
        aws_s3_bucket.pipeline_artifacts[0].arn,
        "${aws_s3_bucket.pipeline_artifacts[0].arn}/*",
      ]
      Condition = {
        Bool = { "aws:SecureTransport" = "false" }
      }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.pipeline_artifacts]
}

resource "aws_iam_role" "codepipeline" {
  count = module.guard.resource_count
  name  = "cloudcart-codepipeline"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codepipeline" {
  count = module.guard.resource_count
  name  = "codepipeline"
  role  = aws_iam_role.codepipeline[0].id

  lifecycle {
    precondition {
      condition     = var.codestar_connection_arn != "" && !strcontains(var.codestar_connection_arn, "000000000000")
      error_message = "An approved pipeline apply needs a real CodeStar connection ARN. The zero account id is rejected."
    }
  }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:AbortMultipartUpload",
        ]
        Resource = "${aws_s3_bucket.pipeline_artifacts[0].arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketVersioning", "s3:GetBucketLocation"]
        Resource = aws_s3_bucket.pipeline_artifacts[0].arn
      },
      {
        Effect   = "Allow"
        Action   = ["codebuild:BatchGetBuilds", "codebuild:StartBuild"]
        Resource = aws_codebuild_project.app[0].arn
      },
      {
        Effect   = "Allow"
        Action   = ["codedeploy:CreateDeployment", "codedeploy:GetDeployment", "codedeploy:GetApplicationRevision", "codedeploy:RegisterApplicationRevision"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["codestar-connections:UseConnection"]
        Resource = var.codestar_connection_arn
      }
    ]
  })
}

resource "aws_codepipeline" "app" {
  count    = module.guard.resource_count
  name     = "cloudcart"
  role_arn = aws_iam_role.codepipeline[0].arn

  lifecycle {
    precondition {
      condition     = var.codestar_connection_arn != "" && !strcontains(var.codestar_connection_arn, "000000000000")
      error_message = "An approved pipeline apply needs a real CodeStar connection ARN. The zero account id is rejected."
    }
  }

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts[0].bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "GitHub"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source"]
      configuration = {
        ConnectionArn    = var.codestar_connection_arn
        FullRepositoryId = "sricharanreddy5414/cloudcart-elevance-internship"
        BranchName       = "main"
        DetectChanges    = "false"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "CodeBuild"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source"]
      output_artifacts = ["build"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.app[0].name
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "CodeDeploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      input_artifacts = ["build"]
      version         = "1"
      configuration = {
        ApplicationName                = aws_codedeploy_app.ecs[0].name
        DeploymentGroupName            = aws_codedeploy_deployment_group.ecs[0].deployment_group_name
        TaskDefinitionTemplateArtifact = "build"
        TaskDefinitionTemplatePath     = "taskdef.json"
        AppSpecTemplateArtifact        = "build"
        AppSpecTemplatePath            = "ci-cd/codedeploy/appspec.yaml"
        Image1ArtifactName             = "build"
        Image1ContainerName            = "IMAGE1_NAME"
      }
    }
  }
}

resource "aws_codebuild_project" "app" {
  count        = module.guard.resource_count
  name         = "cloudcart"
  service_role = aws_iam_role.codebuild[0].arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = file("${path.module}/../../../ci-cd/codebuild/buildspec.yml")
  }
}
