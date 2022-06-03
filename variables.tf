variable "app_name" {
  type        = string
  description = "Application name to name your Fargate API and other resources. Must be <= 24 characters."
}
variable "ecs_cluster_name" {
  type        = string
  description = "ECS Cluster name to host the fargate server. Defaults to creating its own cluster."
  default     = null
}
variable "primary_container_definition" {
  type = object({
    name                  = string
    image                 = string
    ports                 = list(number)
    environment_variables = map(string)
    secrets               = map(string)
    efs_volume_mounts = list(object({
      name           = string
      file_system_id = string
      root_directory = string
      container_path = string
    }))
  })
  description = "The primary container definition for your application. This one will be the only container that receives traffic from the ALB, so make sure the 'ports' field contains the same port as the 'image_port'"
}
variable "extra_container_definitions" {
  type = list(object({
    name                  = string
    image                 = string
    ports                 = list(number)
    environment_variables = map(string)
    secrets               = map(string)
    efs_volume_mounts = list(object({
      name           = string
      file_system_id = string
      root_directory = string
      container_path = string
    }))
  }))
  description = "A list of extra container definitions. Defaults to []"
  default     = []
}
variable "container_port" {
  type        = number
  description = "The port the primary docker container is listening on"
}
variable "health_check_path" {
  type        = string
  description = "Health check path for the image. Defaults to \"/\"."
  default     = "/"
}
variable "health_check_matcher" {
  type        = string
  description = "Expected status code for health check . Defaults to \"200\"."
  default     = "200"
}
variable "health_check_interval" {
  type        = number
  description = "Health check interval; amount of time, in seconds, between health checks of an individual target. Defaults to 30."
  default     = 30
}
variable "health_check_timeout" {
  type        = number
  description = "Health check timeout; amount of time, in seconds, during which no response means a failed health check. Defaults to 5."
  default     = 5
}
variable "health_check_healthy_threshold" {
  type        = number
  description = "Health check healthy threshold; number of consecutive health checks required before considering target as healthy. Defaults to 3."
  default     = 3
}
variable "health_check_unhealthy_threshold" {
  type        = number
  description = "Health check unhealthy threshold; number of consecutive failed health checks required before considering target as unhealthy. Defaults to 3."
  default     = 3
}
variable "health_check_grace_period" {
  type        = number
  description = "Health check grace period in seconds. Defaults to 0."
  default     = 0
}
variable "task_policies" {
  type        = list(string)
  description = "List of IAM Policy ARNs to attach to the task execution policy."
  default     = []
}
variable "task_cpu" {
  type        = number
  description = "CPU for the task definition. Defaults to 256."
  default     = 256
}
variable "task_memory" {
  type        = number
  description = "Memory for the task definition. Defaults to 512."
  default     = 512
}
variable "security_groups" {
  type        = list(string)
  description = "List of extra security group IDs to attach to the fargate task."
  default     = []
}
variable "vpc_id" {
  type        = string
  description = "VPC ID to deploy ECS fargate service."
}
variable "public_subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for the ALB."
}
variable "alb_internal_flag" {
  type        = bool
  default     = false
  description = "Is the ALB Internal"
}

variable "alb_sg_ingress_cidrs" {
  type        = list(string)
  description = "List of cidrs to allow alb ingress for"
  default     = ["0.0.0.0/0"]
}

variable "alb_sg_ingress_sg_ids" {
  type        = list(string)
  description = "List of security groups to allow ingress"
  default     = []
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for the fargate service."
}

variable "codedeploy_service_role_arn" {
  type        = string
  description = "ARN of the IAM Role for the CodeDeploy to use to initiate new deployments. (usually the PowerBuilder Role)"
}
variable "codedeploy_termination_wait_time" {
  type        = number
  description = "The number of minutes to wait after a successful blue/green deployment before terminating instances from the original environment. Defaults to 15"
  default     = 15
}
variable "codedeploy_test_listener_port" {
  type        = number
  description = "The port for a codedeploy test listener. If provided CodeDeploy will use this port for test traffic on the new replacement set during the blue-green deployment process before shifting production traffic to the replacement set. Defaults to null"
  default     = null
}
variable "codedeploy_lifecycle_hooks" {
  type = object({
    BeforeInstall         = string
    AfterInstall          = string
    AfterAllowTestTraffic = string
    BeforeAllowTraffic    = string
    AfterAllowTraffic     = string
  })
  description = "Define Lambda Functions for CodeDeploy lifecycle event hooks. Or set this variable to null to not have any lifecycle hooks invoked. Defaults to null"
  default     = null
}
variable "appspec_filename" {
  type        = string
  description = "`appspec.json` in the current working directory (i.e. where you ran `terraform apply`)"
  default     = null
}
variable "role_permissions_boundary_arn" {
  type        = string
  description = "ARN of the IAM Role permissions boundary to place on each IAM role created."
}
variable "target_group_deregistration_delay" {
  type        = number
  description = "Deregistration delay in seconds for ALB target groups. Defaults to 60 seconds."
  default     = 60
}
variable "target_group_sticky_sessions" {
  type        = string
  description = "Sticky sessions on the ALB target groups. Defaults to false."
  default     = false
}
variable "site_url" {
  type        = string
  description = "The URL for the site."
  default     = null
}
variable "overwrite_records" {
  type        = bool
  description = "Allow creation of Route53 records in Terraform to overwrite an existing record, if any."
  default     = false
}
variable "hosted_zone" {
  type = object({
    name = string,
    id   = string
  })
  description = "Hosted Zone object to redirect to ALB. (Can pass in the aws_hosted_zone object). A and AAAA records created in this hosted zone."
}
variable "https_certificate_arn" {
  type        = string
  description = "ARN of the HTTPS certificate of the hosted zone/domain."
}
variable "autoscaling_config" {
  type = object({
    min_capacity = number
    max_capacity = number
  })
  description = "Configuration for default autoscaling policies and alarms. Set to null if you want to set up your own autoscaling policies and alarms."
}
variable "up_scaling_policy_config" {
  type = object({
    adjustment_type             = string
    metric_aggregation_type     = string
    cooldown                    = number
    scaling_adjustment          = number
    metric_interval_lower_bound = number
  })
  description = "Advanced configuration for the scaling up policy if 'autoscaling_config' is in use."
  default = {
    adjustment_type             = "ChangeInCapacity"
    metric_aggregation_type     = "Average"
    cooldown                    = 300
    scaling_adjustment          = 1
    metric_interval_lower_bound = 0
  }
}
variable "up_metric_alarm_config" {
  type = object({
    statistic           = string
    metric_name         = string
    comparison_operator = string
    threshold           = number
    period              = number
    evaluation_periods  = number
  })
  description = "Advanced configuration for the scaling up metric alarm if 'autoscaling_config' is in use."
  default = {
    statistic           = "Average"
    metric_name         = "CPUUtilization"
    comparison_operator = "GreaterThanThreshold"
    threshold           = 75
    period              = 300
    evaluation_periods  = 5
  }
}
variable "down_scaling_policy_config" {
  type = object({
    adjustment_type             = string
    metric_aggregation_type     = string
    cooldown                    = number
    scaling_adjustment          = number
    metric_interval_upper_bound = number
  })
  description = "Advanced configuration for the scaling down policy if 'autoscaling_config' is in use."
  default = {
    adjustment_type             = "ChangeInCapacity"
    metric_aggregation_type     = "Average"
    cooldown                    = 300
    scaling_adjustment          = -1
    metric_interval_upper_bound = 0
  }
}
variable "down_metric_alarm_config" {
  type = object({
    statistic           = string
    metric_name         = string
    comparison_operator = string
    threshold           = number
    period              = number
    evaluation_periods  = number
  })
  description = "Advanced configuration for scaling the down metric alarm if 'autoscaling_config' is in use."
  default = {
    statistic           = "Average"
    metric_name         = "CPUUtilization"
    comparison_operator = "LessThanThreshold"
    threshold           = 25
    period              = 300
    evaluation_periods  = 5
  }
}
variable "log_group_name" {
  type        = string
  description = "CloudWatch log group name."
  default     = ""
}
variable "log_retention_in_days" {
  type        = number
  description = "CloudWatch log group retention in days. Defaults to 120."
  default     = 120
}
variable "tags" {
  type        = map(string)
  description = "A map of AWS Tags to attach to each resource created"
  default     = {}
}
variable "lb_logging_enabled" {
  type        = bool
  description = "Option to enable logging of load balancer requests."
  default     = false
}
variable "lb_logging_bucket_name" {
  type        = string
  description = "Bucket for ALB access logs."
  default     = ""
}
variable "fargate_platform_version" { # TODO: Add string validation to check for 1.3.0, 1.4.0, or LATEST
  type        = string
  description = "Version of the Fargate platform to run."
  default     = "1.4.0"
}
variable "xray_enabled" {
  type        = bool
  description = "Whether or not the X-Ray daemon should be created with the Fargate API."
  default     = false
}
