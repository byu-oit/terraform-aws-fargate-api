terraform {
  required_version = "0.12.29"
}

provider "aws" {
  version = "~> 3.0"
  region  = "us-west-2"
}

module "acs" {
  source = "github.com/byu-oit/terraform-aws-acs-info?ref=v3.1.0"
}

module "fargate_api" {
  source         = "../../"
  app_name       = "example-api"
  container_port = 8000
  primary_container_definition = {
    name  = "example"
    image = "crccheck/hello-world"
    ports = [8000]
    environment_variables = {
      env = "tst"
    }
    secrets = {
      foo = "/super-secret"
    }
    efs_volume_mounts = null
  }

  autoscaling_config            = null
  codedeploy_test_listener_port = 8443
  codedeploy_lifecycle_hooks = {
    BeforeInstall         = null
    AfterInstall          = null
    AfterAllowTestTraffic = "testLifecycle"
    BeforeAllowTraffic    = null
    AfterAllowTraffic     = null
  }

  hosted_zone                   = module.acs.route53_zone
  https_certificate_arn         = module.acs.certificate.arn
  public_subnet_ids             = module.acs.public_subnet_ids
  private_subnet_ids            = module.acs.private_subnet_ids
  vpc_id                        = module.acs.vpc.id
  codedeploy_service_role_arn   = module.acs.power_builder_role.arn
  role_permissions_boundary_arn = module.acs.role_permissions_boundary.arn
  xray_enabled                  = true

  tags = {
    env              = "dev"
    data-sensitivity = "internal"
    repo             = "https://github.com/byu-oit/terraform-aws-fargate-api"
  }
}

output "fargate_service" {
  value = module.fargate_api.fargate_service.id
}

output "ecs_cluster" {
  value = module.fargate_api.ecs_cluster.arn
}

output "fargate_service_security_group" {
  value = module.fargate_api.fargate_service_security_group.arn
}

output "task_definition" {
  value = module.fargate_api.task_definition.arn
}

output "codedeploy_deployment_group" {
  value = module.fargate_api.codedeploy_deployment_group.id
}

output "codedeploy_appspec_json_file" {
  value = module.fargate_api.codedeploy_appspec_json_file
}

output "alb" {
  value = module.fargate_api.alb.arn
}

output "alb_target_group_blue" {
  value = module.fargate_api.alb_target_group_blue.arn
}

output "alb_target_group_green" {
  value = module.fargate_api.alb_target_group_green.arn
}

output "alb_security_group" {
  value = module.fargate_api.alb_security_group.arn
}

output "dns_record" {
  value = module.fargate_api.dns_record.fqdn
}

output "cloudwatch_log_group" {
  value = module.fargate_api.cloudwatch_log_group.arn
}

output "autoscaling_step_up_policy" {
  value = module.fargate_api.autoscaling_step_up_policy
}

output "autoscaling_step_down_policy" {
  value = module.fargate_api.autoscaling_step_down_policy
}

output "task_role" {
  value = module.fargate_api.task_role
}

output "task_execution_role" {
  value = module.fargate_api.task_execution_role
}
