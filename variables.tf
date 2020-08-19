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
  description = "Filename (including path) to use when outputing appspec json."
  default     = "${path.cwd}/appspec.json"
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
