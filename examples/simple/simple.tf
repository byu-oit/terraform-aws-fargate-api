provider "aws" {
  version = "~> 3.0"
  region  = "us-west-2"
}

module "acs" {
  source = "github.com/byu-oit/terraform-aws-acs-info?ref=v3.0.0"
}

//resource "aws_ecs_cluster" "existing" {
//  name = "fake-example-cluster"
//}
module "fargate_api" {
  source = "github.com/byu-oit/terraform-aws-fargate-api?ref=v3.0.4"
  //  source           = "../../" // for local testing
  app_name = "example-api"
  //  ecs_cluster_name = aws_ecs_cluster.existing.name
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

  tags = {
    env              = "dev"
    data-sensitivity = "internal"
    repo             = "https://github.com/byu-oit/terraform-aws-fargate-api"
  }
}

output "url" {
  value = module.fargate_api.dns_record.fqdn
}

output "appspec_filename" {
  value = module.fargate_api.codedeploy_appspec_json_file
}
