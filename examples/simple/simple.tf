terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

module "acs" {
  source = "github.com/byu-oit/terraform-aws-acs-info?ref=v3.5.0"
}

resource "aws_ecs_cluster" "existing" {
  name = "fake-example-cluster"
}
module "fargate_api" {
  source   = "../../" // for local testing
  app_name = "example-api"
  existing_ecs_cluster = {
    arn  = aws_ecs_cluster.existing.arn
    id   = aws_ecs_cluster.existing.id
    name = aws_ecs_cluster.existing.name
  }
  container_port = 80
  primary_container_definition = {
    name  = "example"
    image = "nginx"
    ports = [80]
  }

  test_listener_port = 8443

  hosted_zone                   = module.acs.route53_zone
  https_certificate_arn         = module.acs.certificate.arn
  public_subnet_ids             = module.acs.public_subnet_ids
  private_subnet_ids            = module.acs.private_subnet_ids
  vpc_id                        = module.acs.vpc.id
  role_permissions_boundary_arn = module.acs.role_permissions_boundary.arn

  tags = {
    env              = "dev"
    data-sensitivity = "internal"
    repo             = "https://github.com/byu-oit/terraform-aws-fargate-api"
  }
}

output "url" {
  value = module.fargate_api.dns_record.fqdn
}

output "task_definition" {
  value = "${module.fargate_api.task_definition.family}:${module.fargate_api.task_definition.revision}"
}

output "deploy_now_command" {
  value = "aws ecs update-service --cluster ${aws_ecs_cluster.existing.name} --service ${module.fargate_api.fargate_service.name} --task-definition ${module.fargate_api.task_definition.family}:${module.fargate_api.task_definition.revision} --force-new-deployment"
}