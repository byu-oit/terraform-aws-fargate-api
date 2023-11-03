terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = ">= 4.0"
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  create_new_cluster = var.existing_ecs_cluster == null ? true : false
  cluster_name       = local.create_new_cluster ? var.app_name : var.existing_ecs_cluster.name
  definitions        = concat([var.primary_container_definition], var.extra_container_definitions)
  volumes = distinct(flatten([
    for def in local.definitions :
    def.efs_volume_mounts != null ? def.efs_volume_mounts : []
  ]))
  ssm_parameters = distinct(flatten([
    for def in local.definitions :
    values(def.secrets != null ? def.secrets : {})
  ]))
  has_secrets            = length(local.ssm_parameters) > 0
  ssm_parameter_arn_base = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/"
  secrets_arns = [
    for param in local.ssm_parameters :
    "${local.ssm_parameter_arn_base}${replace(param, "/^//", "")}"
  ]

  alb_name                       = "${var.app_name}-alb"                                                           // ALB name has a restriction of 32 characters max
  app_domain_url                 = var.site_url != null ? var.site_url : "${var.app_name}.${var.hosted_zone.name}" // Route53 A record name
  cloudwatch_log_group_name      = length(var.log_group_name) > 0 ? var.log_group_name : "fargate/${var.app_name}" // CloudWatch Log Group name
  xray_cloudwatch_log_group_name = "${local.cloudwatch_log_group_name}-xray"
  service_name                   = var.app_name // ECS Service name

  user_containers = [
    for def in local.definitions : {
      name       = def.name
      image      = def.image
      essential  = true
      privileged = false
      portMappings = [
        for port in def.ports :
        {
          containerPort = port
          hostPort      = port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = local.cloudwatch_log_group_name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = local.service_name
        }
      }
      environment = [
        for key in keys(def.environment_variables != null ? def.environment_variables : {}) :
        {
          name  = key
          value = lookup(def.environment_variables, key)
        }
      ]
      secrets = [
        for key in keys(def.secrets != null ? def.secrets : {}) :
        {
          name      = key
          valueFrom = "${local.ssm_parameter_arn_base}${replace(lookup(def.secrets, key), "/^//", "")}"
        }
      ]
      mountPoints = [
        for mount in(def.efs_volume_mounts != null ? def.efs_volume_mounts : []) :
        {
          containerPath = mount.container_path
          sourceVolume  = mount.name
          readOnly      = false
        }
      ]
      volumesFrom = []
      ulimits = [
        for ulimit in(def.ulimits != null ? def.ulimits : []) :
        {
          name      = ulimit.name
          softLimit = ulimit.soft_limit
          hardLimit = ulimit.hard_limit
        }
      ]
    }
  ]
  xray_container = [{
    name       = "${var.app_name}-xray"
    image      = "public.ecr.aws/xray/aws-xray-daemon:3.x"
    essential  = true
    privileged = false
    portMappings = [{
      containerPort = 2000
      hostPort      = null
      protocol      = "udp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = local.xray_cloudwatch_log_group_name
        awslogs-region        = data.aws_region.current.name
        awslogs-stream-prefix = "${local.service_name}-xray"
      }
    }
    environment = []
    secrets     = []
    mountPoints = []
    volumesFrom = []
    ulimits     = []
  }]
  container_definitions = var.xray_enabled == true ? concat(local.user_containers, local.xray_container) : local.user_containers

  hooks = var.codedeploy_lifecycle_hooks != null ? setsubtract([
    for hook in keys(var.codedeploy_lifecycle_hooks) :
    zipmap([hook], [lookup(var.codedeploy_lifecycle_hooks, hook, null)])
    ], [
    {
      BeforeInstall = null
    },
    {
      AfterInstall = null
    },
    {
      AfterAllowTestTraffic = null
    },
    {
      BeforeAllowTraffic = null
    },
    {
      AfterAllowTraffic = null
    }
  ]) : null
}

# ==================== ALB ====================
resource "aws_alb" "alb" {
  name                   = local.alb_name
  desync_mitigation_mode = "strictest"
  subnets                = var.public_subnet_ids
  security_groups        = [aws_security_group.alb-sg.id]
  tags                   = var.tags
  internal               = var.alb_internal_flag

  access_logs {
    bucket  = var.lb_logging_bucket_name
    enabled = var.lb_logging_enabled
  }
}

resource "aws_security_group" "alb-sg" {
  name        = "${local.alb_name}-sg"
  description = "Controls access to the ${local.alb_name}"
  vpc_id      = var.vpc_id

  // allow access to the ALB from anywhere for 80 and 443
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    cidr_blocks     = var.alb_sg_ingress_cidrs
    security_groups = var.alb_sg_ingress_sg_ids
  }
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks     = var.alb_sg_ingress_cidrs
    security_groups = var.alb_sg_ingress_sg_ids
  }
  // if test listener port is specified, allow traffic
  dynamic "ingress" {
    for_each = var.codedeploy_test_listener_port != null ? [1] : []
    content {
      from_port       = var.codedeploy_test_listener_port
      to_port         = var.codedeploy_test_listener_port
      protocol        = "tcp"
      cidr_blocks     = var.alb_sg_ingress_cidrs
      security_groups = var.alb_sg_ingress_sg_ids
    }
  }
  // allow any outgoing traffic
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}
resource "aws_alb_target_group" "blue" {
  name     = "${var.app_name}-tgb"
  port     = var.container_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  load_balancing_algorithm_type = "least_outstanding_requests"
  target_type                   = "ip"
  deregistration_delay          = var.target_group_deregistration_delay
  stickiness {
    type    = "lb_cookie"
    enabled = var.target_group_sticky_sessions
  }
  health_check {
    path                = var.health_check_path
    matcher             = var.health_check_matcher
    interval            = var.health_check_interval
    timeout             = var.health_check_timeout
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
  }
  tags = var.tags

  depends_on = [aws_alb.alb]
}
resource "aws_alb_target_group" "green" {
  name     = "${var.app_name}-tgg"
  port     = var.container_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  load_balancing_algorithm_type = "least_outstanding_requests"
  target_type                   = "ip"
  deregistration_delay          = var.target_group_deregistration_delay
  stickiness {
    type    = "lb_cookie"
    enabled = var.target_group_sticky_sessions
  }
  health_check {
    path                = var.health_check_path
    matcher             = var.health_check_matcher
    interval            = var.health_check_interval
    timeout             = var.health_check_timeout
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
  }
  tags = var.tags

  depends_on = [aws_alb.alb]
}
resource "aws_alb_listener" "https" {
  load_balancer_arn = aws_alb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.https_certificate_arn
  default_action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_alb_target_group.blue.arn
        weight = 100
      }
    }
  }
  lifecycle {
    // CodeDeploy will switch the target groups back and forth for the listener, so ignore them and let CodeDeploy manage target groups
    ignore_changes = [
      default_action[0].target_group_arn,
      default_action[0].forward[0].target_group
    ]
  }
  depends_on = [
    aws_alb_target_group.blue,
    aws_alb_target_group.green
  ]
}
resource "aws_alb_listener" "http_to_https" {
  load_balancer_arn = aws_alb.alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      status_code = "HTTP_301"
      port        = aws_alb_listener.https.port
      protocol    = aws_alb_listener.https.protocol
    }
  }
}
resource "aws_alb_listener" "test_listener" {
  count             = var.codedeploy_test_listener_port != null ? 1 : 0
  load_balancer_arn = aws_alb.alb.arn
  port              = var.codedeploy_test_listener_port
  protocol          = "HTTPS"
  certificate_arn   = var.https_certificate_arn
  default_action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_alb_target_group.blue.arn
        weight = 100
      }
    }
  }
  lifecycle {
    // CodeDeploy will switch the target groups back and forth for the listener, so ignore them and let CodeDeploy manage target groups
    ignore_changes = [
      default_action[0].target_group_arn,
      default_action[0].forward[0].target_group
    ]
  }
  depends_on = [
    aws_alb_target_group.blue,
    aws_alb_target_group.green
  ]
}

# ==================== Route53 ====================
resource "aws_route53_record" "a_record" {
  name            = local.app_domain_url
  type            = "A"
  zone_id         = var.hosted_zone.id
  allow_overwrite = var.overwrite_records
  alias {
    evaluate_target_health = true
    name                   = aws_alb.alb.dns_name
    zone_id                = aws_alb.alb.zone_id
  }
}
resource "aws_route53_record" "aaaa_record" {
  name            = local.app_domain_url
  type            = "AAAA"
  zone_id         = var.hosted_zone.id
  allow_overwrite = var.overwrite_records
  alias {
    evaluate_target_health = true
    name                   = aws_alb.alb.dns_name
    zone_id                = aws_alb.alb.zone_id
  }
}

# ==================== Task Definition ====================
# --- task execution role ---
data "aws_iam_policy_document" "task_execution_policy" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      identifiers = ["ecs-tasks.amazonaws.com"]
      type        = "Service"
    }
  }
}
resource "aws_iam_role" "task_execution_role" {
  name                 = "${var.app_name}-taskExecutionRole"
  assume_role_policy   = data.aws_iam_policy_document.task_execution_policy.json
  permissions_boundary = var.role_permissions_boundary_arn
  tags                 = var.tags
}
resource "aws_iam_role_policy_attachment" "task_execution_policy_attach" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.task_execution_role.name
}
// Make sure the fargate task has access to get the parameters from the container secrets
data "aws_iam_policy_document" "secrets_access" {
  count   = local.has_secrets ? 1 : 0
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameters",
      "ssm:GetParameter",
      "ssm:GetParametersByPath"
    ]
    resources = local.secrets_arns
  }
}
resource "aws_iam_policy" "secrets_access" {
  count  = local.has_secrets ? 1 : 0
  name   = "${var.app_name}_secrets_access"
  policy = data.aws_iam_policy_document.secrets_access[0].json
}
resource "aws_iam_role_policy_attachment" "secrets_policy_attach" {
  count      = local.has_secrets ? 1 : 0
  policy_arn = aws_iam_policy.secrets_access[0].arn
  role       = aws_iam_role.task_execution_role.name
}
# --- task role ---
data "aws_iam_policy_document" "task_policy" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    principals {
      identifiers = ["ecs-tasks.amazonaws.com"]
      type        = "Service"
    }
    actions = ["sts:AssumeRole"]
  }
}
resource "aws_iam_role" "task_role" {
  name                 = "${var.app_name}-taskRole"
  assume_role_policy   = data.aws_iam_policy_document.task_policy.json
  permissions_boundary = var.role_permissions_boundary_arn
  tags                 = var.tags
}
resource "aws_iam_role_policy_attachment" "task_policy_attach" {
  count      = length(var.task_policies)
  policy_arn = element(var.task_policies, count.index)
  role       = aws_iam_role.task_role.name
}
resource "aws_iam_role_policy_attachment" "secret_task_policy_attach" {
  count      = local.has_secrets ? 1 : 0
  policy_arn = aws_iam_policy.secrets_access[0].arn
  role       = aws_iam_role.task_role.name
}
resource "aws_iam_role_policy_attachment" "xray_task_policy_attach" {
  count      = var.xray_enabled == true ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
  role       = aws_iam_role.task_role.name
}
# --- task definition ---
resource "aws_ecs_task_definition" "task_def" {
  container_definitions = jsonencode(local.container_definitions)
  family                = "${var.app_name}-def"
  cpu                   = var.task_cpu
  memory                = var.task_memory
  network_mode          = "awsvpc"
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  task_role_arn            = aws_iam_role.task_role.arn
  tags                     = var.tags

  dynamic "volume" {
    for_each = local.volumes
    content {
      name = volume.value.name
      efs_volume_configuration {
        file_system_id = volume.value.file_system_id
        root_directory = volume.value.root_directory
      }
    }
  }
}

# ==================== Fargate ====================
resource "aws_ecs_cluster" "new_cluster" {
  count = local.create_new_cluster ? 1 : 0 # if cluster is not provided create one
  name  = local.cluster_name
  tags  = var.tags
}
resource "aws_security_group" "fargate_service_sg" {
  name        = "${var.app_name}-fargate-sg"
  description = "Controls access to the Fargate Service"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb-sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}
resource "aws_ecs_service" "service" {
  name             = local.service_name
  task_definition  = aws_ecs_task_definition.task_def.arn
  cluster          = local.create_new_cluster ? aws_ecs_cluster.new_cluster[0].id : var.existing_ecs_cluster.arn # if cluster is not provided use created one, else use existing cluster
  desired_count    = var.autoscaling_config != null ? var.autoscaling_config.min_capacity : 1
  launch_type      = "FARGATE"
  platform_version = var.fargate_platform_version
  deployment_controller {
    type = "CODE_DEPLOY"
  }
  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = concat([aws_security_group.fargate_service_sg.id], var.security_groups)
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.blue.arn
    container_name   = var.primary_container_definition.name
    container_port   = var.container_port
  }

  health_check_grace_period_seconds = var.health_check_grace_period

  tags = var.tags

  lifecycle {
    ignore_changes = [
      task_definition,      // ignore because new revisions will get added after code deploy's blue-green deployment
      load_balancer,        // ignore because load balancer can change after code deploy's blue-green deployment
      desired_count,        // ignore because we're assuming you have autoscaling to manage the container count
      network_configuration // ignore because it has to be managed by codedeploy
    ]
  }
}

# ==================== CodeDeploy ====================
resource "aws_codedeploy_app" "app" {
  name             = "${var.app_name}-codedeploy"
  compute_platform = "ECS"
}

resource "aws_codedeploy_deployment_group" "deploymentgroup" {
  app_name               = aws_codedeploy_app.app.name
  deployment_group_name  = "${var.app_name}-deployment-group"
  service_role_arn       = var.codedeploy_service_role_arn
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

  ecs_service {
    cluster_name = local.cluster_name
    service_name = aws_ecs_service.service.name
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = var.codedeploy_termination_wait_time
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_alb_listener.https.arn]
      }
      test_traffic_route {
        listener_arns = var.codedeploy_test_listener_port != null ? [aws_alb_listener.test_listener[0].arn] : []
      }
      target_group {
        name = aws_alb_target_group.blue.name
      }
      target_group {
        name = aws_alb_target_group.green.name
      }
    }
  }
}

# ==================== CloudWatch ====================
resource "aws_cloudwatch_log_group" "container_log_group" {
  name              = local.cloudwatch_log_group_name
  retention_in_days = var.log_retention_in_days
  tags              = var.tags
}
resource "aws_cloudwatch_log_group" "xray_log_group" {
  count             = (var.xray_enabled == true) ? 1 : 0
  name              = local.xray_cloudwatch_log_group_name
  retention_in_days = var.log_retention_in_days
  tags              = var.tags
}

# ==================== AutoScaling ====================
resource "aws_appautoscaling_target" "default" {
  count              = var.autoscaling_config != null ? 1 : 0
  min_capacity       = var.autoscaling_config.min_capacity
  max_capacity       = var.autoscaling_config.max_capacity
  resource_id        = "service/${local.cluster_name}/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "default" {
  count              = var.autoscaling_config != null ? 1 : 0
  name               = "${var.app_name}-tracking-autoscale"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.default[0].resource_id
  scalable_dimension = aws_appautoscaling_target.default[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.default[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = var.autoscaling_config.target_metric
    }
    target_value       = var.autoscaling_config.target_value
    scale_in_cooldown  = var.autoscaling_config.scale_in_cooldown
    scale_out_cooldown = var.autoscaling_config.scale_out_cooldown
  }
}


# ==================== AppSpec file ====================
resource "local_file" "appspec_json" {
  filename = var.appspec_filename != null ? var.appspec_filename : "${path.cwd}/appspec.json"
  content = jsonencode({
    version = 1
    Resources = [{
      TargetService = {
        Type = "AWS::ECS::SERVICE"
        Properties = {
          TaskDefinition = aws_ecs_task_definition.task_def.arn
          LoadBalancerInfo = {
            ContainerName = var.primary_container_definition.name
            ContainerPort = var.container_port
          }
          PlatformVersion = var.fargate_platform_version
          NetworkConfiguration = {
            AwsvpcConfiguration = {
              Subnets        = var.private_subnet_ids
              SecurityGroups = concat([aws_security_group.fargate_service_sg.id], var.security_groups)
              AssignPublicIp = "DISABLED"
            }
          }
        }
      }
    }],
    Hooks = local.hooks
  })
}
