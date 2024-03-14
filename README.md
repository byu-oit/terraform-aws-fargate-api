![Latest GitHub Release](https://img.shields.io/github/v/release/byu-oit/terraform-aws-fargate-api?sort=semver)

# Terraform AWS Fargate API

Terraform module pattern to build a standard Fargate API.

This module creates a Fargate service with an ALB, AutoScaling, CodeDeploy configuration and a DNS record in front.

**Note:** This module has many preset standards to make creating an API using Fargate easy. If you require a more
customized solution you may need to use this code more as a pattern or guideline in how to build the resources you need.

## Usage

```hcl
module "my_app" {
  source                       = "github.com/byu-oit/terraform-aws-fargate-api?ref=v6.1.3"
  app_name                     = "example-api"
  container_port               = 8000
  primary_container_definition = {
    name                  = "example"
    image                 = "crccheck/hello-world"
    ports                 = [8000]
    environment_variables = null
    secrets               = null
    efs_volume_mounts     = null
    ulimits               = null
  }

  autoscaling_config            = null
  codedeploy_test_listener_port = 8443
  codedeploy_lifecycle_hooks    = {
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
```
> **Note**
> * If your application's `site_url` is a subdomain within your AWS account's default hosted zone, you must input both the default Route53 zone object and the default zone's ACM certificate arn from the [terraform-aws-acs-info module's](https://github.com/byu-oit/terraform-aws-acs-info) output. This is shown in the example above.
> * If your application requires a custom `site_url` outside of your AWS account's default hosted zone, input a custom `hosted_zone` and do not input `https_certificate_arn`. The module will create an ACM certificate for your custom hosted zone.

## Created Resources

* ECS Cluster (if not provided)
* ECS Service
    * with security group
* ECS Task Definition
    * with IAM role
* CloudWatch Log Group
* ALB
    * with security group
* 2 Target Groups (for blue-green deployment)
* CodeDeploy App
    * with IAM role
* CodeDeploy Group
* DNS A-Record
* HTTPS Certificate (if not provided)
  * with DNS validation record
* AutoScaling Target
* AutoScaling Policies (one for stepping up and one for stepping down)
* CloudWatch Metric Alarms (one for stepping up and one for stepping down)

## Requirements

* Terraform version 1.3.0 or greater

## Inputs

| Name                              | Type                                        | Description                                                                                                                                                                                                                                                                                                                                                                                          | Default                                                                                |
|-----------------------------------|---------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------|
| app_name                          | string                                      | Application name to name your Fargate API and other resources (Must be <= 24 alphanumeric characters)                                                                                                                                                                                                                                                                                                |                                                                                        |
| primary_container_definition      | [object](#container_definition)             | The primary container definition for your application. This one will be the only container that receives traffic from the ALB, so make sure the `ports` field contains the same port as the `image_port`                                                                                                                                                                                             |                                                                                        |
| extra_container_definitions       | list([object](#container_definition))       | A list of extra container definitions (side car containers)                                                                                                                                                                                                                                                                                                                                          | []                                                                                     |
| existing_ecs_cluster              | [object](#existing_ecs_cluster)             | Existing ECS Cluster configuration to host the fargate server. Defaults to creating its own cluster.	                                                                                                                                                                                                                                                                                                | <app_name>                                                                             |
| container_port                    | number                                      | The port the primary docker container is listening on                                                                                                                                                                                                                                                                                                                                                |                                                                                        |
| health_check_path                 | string                                      | Health check path for the image                                                                                                                                                                                                                                                                                                                                                                      | "/"                                                                                    |
| health_check_matcher              | string                                      | Expected status code for health check. [See docs for syntax](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html)                                                                                                                                                                                                                                    | 200                                                                                    | 
| health_check_interval             | number                                      | Amount of time, in seconds, between health checks of an individual target                                                                                                                                                                                                                                                                                                                            | 30                                                                                     |
| health_check_timeout              | number                                      | Amount of time, in seconds, during which no response means a failed health check                                                                                                                                                                                                                                                                                                                     | 5                                                                                      |
| health_check_healthy_threshold    | number                                      | Number of consecutive health checks required before considering target as healthy                                                                                                                                                                                                                                                                                                                    | 3                                                                                      |
| health_check_unhealthy_threshold  | number                                      | Number of consecutive failed health checks required before considering target as unhealthy                                                                                                                                                                                                                                                                                                           | 3                                                                                      |
| health_check_grace_period         | number                                      | Health check grace period in seconds                                                                                                                                                                                                                                                                                                                                                                 | 0                                                                                      |
| task_policies                     | list(string)                                | List of IAM Policy ARNs to attach to the task execution IAM Policy                                                                                                                                                                                                                                                                                                                                   | []                                                                                     |
| task_cpu                          | number                                      | CPU for the task definition                                                                                                                                                                                                                                                                                                                                                                          | 256                                                                                    |
| task_memory                       | number                                      | Memory for the task definition                                                                                                                                                                                                                                                                                                                                                                       | 512                                                                                    |
| cpu_architecture                  | string                                      | CPU architecture for the task definition. [See docs for options](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html#runtime-platform)                                                                                                                                                                                                                       | "X86_64"                                                                               |
| security_groups                   | list(string)                                | List of extra security group IDs to attach to the fargate task                                                                                                                                                                                                                                                                                                                                       | []                                                                                     |
| vpc_id                            | string                                      | VPC ID to deploy the ECS fargate service and ALB                                                                                                                                                                                                                                                                                                                                                     |                                                                                        |
| public_subnet_ids                 | list(string)                                | List of subnet IDs for the ALB                                                                                                                                                                                                                                                                                                                                                                       |                                                                                        |
| alb_internal_flag                 | bool                                        | Marks an ALB as Internal (Inaccessible to public internet)                                                                                                                                                                                                                                                                                                                                           | false                                                                                  |
| alb_sg_ingress_cidrs              | list(string)                                | List of cidrs to allow alb ingress for                                                                                                                                                                                                                                                                                                                                                               | ["0.0.0.0/0"]                                                                          |
| alb_sg_ingress_sg_ids             | list(string)                                | List of security groups to allow ingress                                                                                                                                                                                                                                                                                                                                                             | []                                                                                     |
| alb_idle_timeout                  | number                                      | The time in seconds that the connection is allowed to be idle. Defaults to 60 seconds.                                                                                                                                                                                                                                                                                                               |
| private_subnet_ids                | list(string)                                | List of subnet IDs for the fargate service                                                                                                                                                                                                                                                                                                                                                           |                                                                                        |
| codedeploy_service_role_arn       | string                                      | ARN of the IAM Role for the CodeDeploy to use to initiate new deployments. (usually the PowerBuilder Role)                                                                                                                                                                                                                                                                                           |                                                                                        |
| codedeploy_termination_wait_time  | number                                      | the number of minutes to wait after a successful blue/green deployment before terminating instances from the original environment                                                                                                                                                                                                                                                                    | 15                                                                                     |
| codedeploy_test_listener_port     | number                                      | The port for a codedeploy test listener. If provided CodeDeploy will use this port for test traffic on the new replacement set during the blue-green deployment process before shifting production traffic to the replacement set                                                                                                                                                                    | `null`                                                                                 |
| codedeploy_lifecycle_hooks        | [object](#codedeploy_lifecycle_hooks)       | Define Lambda Functions for each CodeDeploy [lifecycle event hooks](https://docs.aws.amazon.com/codedeploy/latest/userguide/reference-appspec-file-structure-hooks.html). Use the Lambda function names as the values. Omit or set specific hooks to `null` if you don't want to invoke a lambda function at that hook. Omit or set this variable to `null` to not have any lifecycle hooks invoked. | `null`                                                                                 |
| appspec_filename                  | string                                      | Filename (including path) to use when outputing appspec json.                                                                                                                                                                                                                                                                                                                                        | `appspec.json` in the current working directory (i.e. where you ran `terraform apply`) |
| role_permissions_boundary_arn     | string                                      | ARN of the IAM Role permissions boundary to place on each IAM role created                                                                                                                                                                                                                                                                                                                           |                                                                                        |
| target_group_deregistration_delay | number                                      | Deregistration delay in seconds for ALB target groups                                                                                                                                                                                                                                                                                                                                                | 60                                                                                     |
| target_group_sticky_sessions      | boolean                                     | Enables sticky sessions on the ALB target groups                                                                                                                                                                                                                                                                                                                                                     | false                                                                                  |
| site_url                          | string                                      | The URL for the site.                                                                                                                                                                                                                                                                                                                                                                                | Concatenates app_name with hosted_zone_name.                                           |
| overwrite_records                 | bool                                        | Allow creation of Route53 records in Terraform to overwrite an existing record, if any.                                                                                                                                                                                                                                                                                                              | false                                                                                  |
| hosted_zone                       | [object](#hosted_zone)                      | Hosted Zone object to redirect to ALB. (Can pass in the aws_hosted_zone object). A and AAAA records created in this hosted zone                                                                                                                                                                                                                                                                      |                                                                                        |
| https_certificate_arn             | string                                      | ARN of the HTTPS certificate of the hosted zone/domain. Defaults to creating its own certificate.                                                                                                                                                                                                                                                                                                    | `null`                                                                                  |
| autoscaling_config                | [object](#autoscaling_config)               | Configuration for default autoscaling policies and alarms. Additional advanced scaling options, which are optional, can be made with the "scaling_up_policy_config", "scaling_up_metric_alarm_config", "scaling_down_policy_config", and "scaling_down_metric_alarm_config" variables. Omit or set to `null` if you want to set up your own autoscaling policies and alarms.                         | `null`                                                                                 |
| scaling_up_policy_config          | [object](#scaling_up_policy_config)         | Optional advanced configuration for the scaling up policy if 'autoscaling_config' is in use.                                                                                                                                                                                                                                                                                                         | See object definition [object](#scaling_up_policy_config)                              |                                                                        
| scaling_up_metric_alarm_config    | [object](#scaling_up_metric_alarm_config)   | Optional advanced configuration for the scaling up metric alarm if 'autoscaling_config' is in use.                                                                                                                                                                                                                                                                                                   | See object definition [object](#scaling_up_metric_alarm_config)                        |                                                                        
| scaling_down_policy_config        | [object](#scaling_down_policy_config)       | Optional advanced configuration for the scaling down policy if 'autoscaling_config' is in use.                                                                                                                                                                                                                                                                                                       | See object definition [object](#scaling_down_policy_config)                            |                                                                        
| scaling_down_metric_alarm_config  | [object](#scaling_down_metric_alarm_config) | Optional advanced configuration for scaling the down metric alarm if 'autoscaling_config' is in use."                                                                                                                                                                                                                                                                                                | See object definition [object](#scaling_down_metric_alarm_config)                      |
| log_group_name                    | string                                      | CloudWatch log group name.                                                                                                                                                                                                                                                                                                                                                                           |                                                                                        |
| log_retention_in_days             | number                                      | CloudWatch log group retention in days                                                                                                                                                                                                                                                                                                                                                               | 120                                                                                    |
| tags                              | map(string)                                 | A map of AWS Tags to attach to each resource created                                                                                                                                                                                                                                                                                                                                                 | `null`                                                                                 |
| lb_logging_enabled                | bool                                        | Option to enable logging of load balancer requests.                                                                                                                                                                                                                                                                                                                                                  | false                                                                                  |
| lb_logging_bucket_name            | string                                      | Required if `lb_logging_enabled` is true. A bucket to store the logs in with an a [load balancer access policy](https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/enable-access-logs.html#attach-bucket-policy) attached.                                                                                                                                                              |                                                                                        |
| fargate_platform_version          | string                                      | Version of the Fargate platform to run.                                                                                                                                                                                                                                                                                                                                                              | 1.4.0                                                                                  |
| xray_enabled                      | bool                                        | Whether or not the X-Ray daemon should be created with the Fargate API.                                                                                                                                                                                                                                                                                                                              | false                                                                                  |

#### existing_ecs_cluster
Object with following attributes to define an existing ECS cluster to deploy the fargate tasks.
* **`arn`** - (Required) string of the ARN of the existing ECS cluster
* **`name`** - (Required) string of the name of the existing ECS cluster

If you want to deploy this scheduled fargate task onto an existing cluster you would need to define this variable. For example:
```hcl
module "test_api" {
  source = "github.com/byu-oit/terraform-aws-fargate-api?ref=v6.1.1"
  app_name             = "example-api"
  existing_ecs_cluster = {
    arn  = aws_ecs_cluster.my_cluster.arn
    name = aws_ecs_cluster.my_cluster.name
  }
  // ...
}
```

#### container_definition

Object with following attributes to define the docker container(s) your fargate needs to run.

* **`name`** - (Required) container name (referenced in CloudWatch logs, and possibly by other containers)
* **`image`** - (Required) the ecr_image_url with the tag like: `<acct_num>.dkr.ecr.us-west-2.amazonaws.com/myapp:dev`
  or the image URL from dockerHub or some other docker registry
* **`ports`** - (Required) a list of ports this container is listening on
* **`environment_variables`** - a map of environment variables to pass to the docker container
* **`secrets`** - a map of secrets from the parameter store to be assigned to env variables
* **`efs_volume_mounts`** - a list of efs_volume_mount [objects](#efs_volume_mount) to be mounted into the
  container.
* **`ulimits`** - a list of ulimit [objects](#ulimit) to be set on the container.

**Before running this configuration** make sure that your ECR repo exists and an image has been pushed to the repo.

#### efs_volume_mount

Example

```
    efs_volume_mounts = [
      {
        name = "persistent_data"
        file_system_id = aws_efs_file_system.my_efs.id
        root_directory = "/"
        container_path = "/usr/app/data"
      }
    ]
```

* **`name`** - A logical name used to describe what the mount is for.
* **`file_system_id`** - ID of the EFS to mount.
* **`root_directory`** - Source path inside the EFS.
* **`container_path`** - Target path inside the container.

See the following docs for more details:

* https://www.terraform.io/docs/providers/aws/r/ecs_task_definition.html#volume-block-arguments
* https://www.terraform.io/docs/providers/aws/r/ecs_task_definition.html#efs-volume-configuration-arguments
* https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_ContainerDefinition.html
* https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_MountPoint.html

#### ulimit

Example

```
    ulimits = [
      {
        name = "nofile"
        soft_limit = 2048
        hard_limit = 8192
      }
    ]
```

See the following docs for more details:

* https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_ContainerDefinition.html
* https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_Ulimit.html

#### codedeploy_lifecycle_hooks

This variable is used when generating the [appspec.json](#appspec) file. This will define what Lambda Functions to
invoke at
specific [lifecycle hooks](https://docs.aws.amazon.com/codedeploy/latest/userguide/reference-appspec-file-structure-hooks.html)
. Omit this variable or set it to `null` if you don't want to invoke any lambda functions. Omit or set a hook to `null` if you don't
need that specific lifecycle hook function.

* **`before_install`** - lambda function name to run before new task set is created
* **`after_install`** - lambda function name to run after new task set is created before test traffic points to new task
  set
* **`after_allow_test_traffic`** - lambda function name to run after test traffic points to new task set
* **`before_allow_traffic`** - lambda function name to run before public traffic points to new task set
* **`after_allow_traffic`** - lambda function name to run after public traffic points to new task set

#### hosted_zone

You can pass in either the object from the AWS terraform provider for an AWS Hosted Zone, or just an object with the
following attributes:

* **`name`** - (Required) Name of the hosted zone
* **`id`** - (Required) ID of the hosted zone

#### autoscaling_config

This module will create basic default autoscaling policies and alarms and you can define some variables of these default
autoscaling policies.

* **`min_capacity`** - (Required) Minimum task count for autoscaling (this will also be used to define the initial
  desired count of the ECS Fargate Service)
* **`max_capacity`** - (Required) Maximum task count for autoscaling

**Note:** If you want to define your own autoscaling policies/alarms then you need to set this field to `null` at which
point this module will not create any policies/alarms.

**Note:** the desired count of the ECS Fargate Service will be set the first time terraform runs but changes to desired
count will be ignored after the first time.

#### scaling_up_policy_config

This will allow the scaling up policy to be configured if necessary.

* **`adjustment_type`** - (Required) Specifies whether the adjustment is an absolute number or a percentage of the
  current capacity.
* **`metric_aggregation_type`** - (Required) The aggregation type for the policy's metrics.
* **`cooldown`** - (Required) The amount of time, in seconds, after a scaling activity completes and before the next
  scaling activity can start.
* **`scaling_adjustment`** - (Required) The number of members by which to scale, when the adjustment bounds are
  breached. A positive value scales up. A negative value scales down.
* **`metric_interval_lower_bound`** - (Required) The lower bound for the difference between the alarm threshold and the
  CloudWatch metric.
* Default:
  ```
    {
      adjustment_type             = "ChangeInCapacity"
      metric_aggregation_type     = "Average"
      cooldown                    = 300
      scaling_adjustment          = 1
      metric_interval_lower_bound = 0
    }
  ```

#### scaling_down_policy_config

This will allow the scaling down policy to be configured if necessary.

* **`adjustment_type`** - (Required) Specifies whether the adjustment is an absolute number or a percentage of the
  current capacity.
* **`metric_aggregation_type`** - (Required) The aggregation type for the policy's metrics.
* **`cooldown`** - (Required) The amount of time, in seconds, after a scaling activity completes and before the next
  scaling activity can start.
* **`scaling_adjustment`** - (Required) The number of members by which to scale, when the adjustment bounds are
  breached. A positive value scales up. A negative value scales down.
* **`metric_interval_upper_bound`** - The upper bound for the difference between the alarm threshold and the CloudWatch
  metric.
* Default:
  ```
    {
      adjustment_type             = "ChangeInCapacity"
      metric_aggregation_type     = "Average"
      cooldown                    = 300
      scaling_adjustment          = -1
      metric_interval_upper_bound = 0
    }
  ```

#### scaling_up_metric_alarm_config

This will allow the scaling up alarm to be configured if necessary.

* **`statistic`** - (Required) The statistic to apply to the alarm's associated metric.
* **`metric_name`** - (Required) The name for the alarm's associated metric.
* **`comparison_operator`** - (Required) The arithmetic operation to use when comparing the specified Statistic and
  Threshold.
* **`threshold`** - (Required) The value against which the specified statistic is compared.
* **`period`** - (Required) The period in seconds over which the specified statistic is applied.
* **`evaluation_periods`** - (Required) The number of periods over which data is compared to the specified threshold.
* Default:
  ```
    {
      statistic           = "Average"
      metric_name         = "CPUUtilization"
      comparison_operator = "GreaterThanThreshold"
      threshold           = 75
      period              = 300
      evaluation_periods  = 5
    }
  ```

#### scaling_down_metric_alarm_config

This will allow the scaling down alarm to be configured if necessary.

* **`statistic`** - (Required) The statistic to apply to the alarm's associated metric.
* **`metric_name`** - (Required) The name for the alarm's associated metric.
* **`comparison_operator`** - (Required) The arithmetic operation to use when comparing the specified Statistic and
  Threshold.
* **`threshold`** - (Required) The value against which the specified statistic is compared.
* **`period`** - (Required) The period in seconds over which the specified statistic is applied.
* **`evaluation_periods`** - (Required) The number of periods over which data is compared to the specified threshold.
* Default:
  ```
    {
      statistic           = "Average"
      metric_name         = "CPUUtilization"
      comparison_operator = "LessThanThreshold"
      threshold           = 25
      period              = 300
      evaluation_periods  = 5
    }
  ```

#### CloudWatch logs

This module will create a CloudWatch log group named `fargate/<app_name>` with log streams
named `<app_name>/<container_name>/<container_id>`.

For instance with the [above example](#usage) the logs could be found in the CloudWatch log group: `fargate/example-api`
with the container logs in `example-api/example/12d344fd34b556ae4326...`

## Outputs

| Name                           | Type                                                                                                                | Description                                                                                                         |
|--------------------------------|---------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------|
| fargate_service                | [object](https://www.terraform.io/docs/providers/aws/r/ecs_service.html#attributes-reference)                       | Fargate ECS Service object                                                                                          |
| new_ecs_cluster                | [object](https://www.terraform.io/docs/providers/aws/r/ecs_cluster.html#attributes-reference)                       | Newly created ECS Cluster the service is deployed on, if var.existing_ecs_cluster is provided this will return null |
| fargate_service_security_group | [object](https://www.terraform.io/docs/providers/aws/r/security_group.html#attributes-reference)                    | Security Group object assigned to the Fargate service                                                               |
| task_definition                | [object](https://www.terraform.io/docs/providers/aws/r/ecs_task_definition.html#attributes-reference)               | The task definition object of the fargate service                                                                   |
| codedeploy_deployment_group    | [object](https://www.terraform.io/docs/providers/aws/r/codedeploy_deployment_group.html#attributes-reference)       | The CodeDeploy deployment group object.                                                                             |
| codedeploy_appspec_json_file   | string                                                                                                              | Filename of the generated appspec.json file                                                                         |
| alb                            | [object](https://www.terraform.io/docs/providers/aws/r/lb.html#attributes-reference)                                | The Application Load Balancer (ALB) object                                                                          |
| alb_target_group_blue          | [object](https://www.terraform.io/docs/providers/aws/r/lb_target_group.html#attributes-reference)                   | The Application Load Balancer Target Group (ALB Target Group) object for the blue deployment                        |
| alb_target_group_green         | [object](https://www.terraform.io/docs/providers/aws/r/lb_target_group.html#attributes-reference)                   | The Application Load Balancer Target Group (ALB Target Group) object  for the green deployment                      |
| alb_security_group             | [object](https://www.terraform.io/docs/providers/aws/r/security_group.html#attributes-reference)                    | The ALB's security group object                                                                                     |
| dns_record                     | [object](https://www.terraform.io/docs/providers/aws/r/route53_record.html#attributes-reference)                    | The DNS A-record mapped to the ALB                                                                                  |
| cloudwatch_log_group           | [object](https://www.terraform.io/docs/providers/aws/r/cloudwatch_log_group#attributes-reference)                   | The CloudWatch Log group for the fargate service                                                                    |
| autoscaling_step_up_policy     | [object](https://www.terraform.io/docs/providers/aws/r/autoscaling_policy.html#attributes-reference)                | Autoscaling policy to step up                                                                                       |
| autoscaling_step_down_policy   | [object](https://www.terraform.io/docs/providers/aws/r/autoscaling_policy.html#attributes-reference)                | Autoscaling policy to step down                                                                                     |
| task_role                      | [object](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role#attributes-reference) | IAM role created for the tasks.                                                                                     |
| task_execution_role            | [object](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role#attributes-reference) | IAM role created for the execution of tasks.                                                                        |

#### appspec

This module also creates a JSON file in the project directory: `appspec.json` used to initiate a CodeDeploy Deployment.

Here's an example appspec.json file this creates:

```json
{
  "Resources": [
    {
      "TargetService": {
        "Properties": {
          "LoadBalancerInfo": {
            "ContainerName": "example",
            "ContainerPort": 8000
          },
          "TaskDefinition": "arn:aws:ecs:us-west-2:123456789123:task-definition/example-api-def:2"
        },
        "Type": "AWS::ECS::SERVICE"
      }
    }
  ],
  "version": 1
}
```

And example with [lifecycle hooks](#codedeploy_lifecycle_hooks):

```json
{
  "Hooks": [
    {
      "BeforeInstall": null
    },
    {
      "AfterInstall": "AfterInstallHookFunctionName"
    },
    {
      "AfterAllowTestTraffic": "AfterAllowTestTrafficHookFunctionName"
    },
    {
      "BeforeAllowTraffic": null
    },
    {
      "AfterAllowTraffic": null
    }
  ],
  "Resources": [
    {
      "TargetService": {
        "Properties": {
          "LoadBalancerInfo": {
            "ContainerName": "example",
            "ContainerPort": 8000
          },
          "TaskDefinition": "arn:aws:ecs:us-west-2:123456789123:task-definition/example-api-def:2"
        },
        "Type": "AWS::ECS::SERVICE"
      }
    }
  ],
  "version": 1
}
```

## CodeDeploy Blue-Green Deployment

This module creates a blue-green deployment process with CodeDeploy. If a `codedeploy_test_listener_port` is provided
this module will create an ALB listener that will allow public traffic from that port to the running fargate service.

When a CodeDeploy deployment is initiated (either via a pipeline or manually) CodeDeploy will:

1. call lambda function defined for `BeforeInstall` hook
2. attempt to create a new set of tasks (called the replacement set) with the new task definition etc. in the unused ALB
   Target Group
3. call lambda function defined for `AfterInstall` hook
4. associate the test listener (if defined) to the new target group
5. call lambda function defined for `AfterAllowTestTraffic` hook
6. call lambda function defined for `BeforeAllowTraffic` hook
7. associate the production listener to the new target group
8. call lambda function defined for `AfterAllowTraffic` hook
9. wait for the `codedeploy_termination_wait_time` in minutes before destroying the original task set (this is useful if
   you need to manually rollback)

At any step (except step #1) the deployment can rollback (either manually or by the lambda functions in the lifecycle
hooks or if there was an error trying to actually deploy)

##### TODO add diagrams to explain the blue-green deployment process

## Note

If you require additional variables please create
an [issue](https://github.com/byu-oit/terraform-aws-fargate-api/issues)
and/or a [pull request](https://github.com/byu-oit/terraform-aws-fargate-api/pulls) to add the variable and reach out to
the Terraform Working Group on slack (`#terraform` channel).
