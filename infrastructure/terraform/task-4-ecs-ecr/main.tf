resource "aws_ecr_repository" "app" {
  count                = module.guard.resource_count
  name                 = "cloudcart"
  image_tag_mutability = "IMMUTABLE"

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
  count  = module.guard.resource_count
  name   = "cloudcart-alb"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
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
        awslogs-region        = "ap-south-1"
        awslogs-stream-prefix = "evershop"
      }
    }
  }])
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
        Resource = "*"
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
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"]
        Resource = "${aws_s3_bucket.pipeline_artifacts[0].arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket" "pipeline_artifacts" {
  count  = module.guard.resource_count
  bucket = "cloudcart-pipeline-artifacts-000000000000"
}

resource "aws_s3_bucket_public_access_block" "pipeline_artifacts" {
  count                   = module.guard.resource_count
  bucket                  = aws_s3_bucket.pipeline_artifacts[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
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
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"]
        Resource = "${aws_s3_bucket.pipeline_artifacts[0].arn}/*"
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
        Resource = var.codestar_connection_arn == "" ? "arn:aws:codeconnections:ap-south-1:000000000000:connection/00000000-0000-0000-0000-000000000000" : var.codestar_connection_arn
      }
    ]
  })
}

resource "aws_codepipeline" "app" {
  count    = module.guard.resource_count
  name     = "cloudcart"
  role_arn = aws_iam_role.codepipeline[0].arn

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
        ConnectionArn    = var.codestar_connection_arn == "" ? "arn:aws:codeconnections:ap-south-1:000000000000:connection/00000000-0000-0000-0000-000000000000" : var.codestar_connection_arn
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
