variable "app_name" {
  type        = string
  description = "Application name to name your Fargate API and other resources"
}
variable "env" {
  type        = string
  description = "Environment of the AWS Account (e.g. dev, prd)"
}

variable "image_port" {
  type        = number
  description = "The port the docker image is listening on"
}
variable "health_check_path" {
  type        = string
  description = "Health check path for the image. Defaults to \"/\"."
  default     = "/"
}
variable "container_env_variables" {
  type        = map(string)
  description = "Map of environment variables to pass to the container definition. Defaults to an empty map."
  default     = {}
}
variable "container_secrets" {
  type        = map(string)
  description = "Map of secrets from the parameter store to be assigned to an env variable. Defaults to an empty map."
  default     = {}
}
variable "task_policies" {
  type        = list(string)
  description = "List of IAM Policy ARNs to attach to the task execution policy."
  default     = []
}
variable "min_capacity" {
  type        = number
  description = "Minimum task count. Defaults to 1."
  default     = 1
}
variable "max_capacity" {
  type        = number
  description = "Maximum task count. Defaults to 2."
  default     = 2
}
variable "tags" {
  type = map(string)
  description = "A map of AWS Tags to attach to each resource created"
  default = {}
}
variable "container_url" {
  type = string
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
  type = list(string)
  description = "Extra security groups"
  default = []
}
variable "vpn_to_campus" {
  type = bool
  description = "VPN to Campus"
  default = false
}
variable "log_retention_in_days" {
  type = number
  default = 7
}
variable "health_check_grace_period" {
  type        = number
  description = "Health check grace period in seconds. Defaults to 0."
  default     = 0
}