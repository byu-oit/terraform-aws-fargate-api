output "fargate_service" {
  value = aws_ecs_service.service
}

output "new_ecs_cluster" {
  value = local.create_new_cluster ? aws_ecs_cluster.new_cluster[0] : null
}

output "fargate_service_security_group" {
  value = aws_security_group.fargate_service_sg
}

output "task_definition" {
  value = aws_ecs_task_definition.task_def
}

output "codedeploy_deployment_group" {
  value = aws_codedeploy_deployment_group.deploymentgroup
}

output "codedeploy_appspec_json_file" {
  value = local_file.appspec_json.filename
}

output "alb" {
  value = aws_alb.alb
}

output "alb_target_group_blue" {
  value = aws_alb_target_group.blue
}

output "alb_target_group_green" {
  value = aws_alb_target_group.green
}

output "alb_security_group" {
  value = aws_security_group.alb-sg
}

output "dns_record" {
  value = aws_route53_record.a_record
}

output "cloudwatch_log_group" {
  value = aws_cloudwatch_log_group.container_log_group
}

output "autoscaling_step_up_policy" {
  value = var.autoscaling_config != null ? aws_appautoscaling_policy.up : null
}

output "autoscaling_step_down_policy" {
  value = var.autoscaling_config != null ? aws_appautoscaling_policy.down : null
}

output "task_role" {
  value     = aws_iam_role.task_role
  sensitive = true
}

output "task_execution_role" {
  value     = aws_iam_role.task_execution_role
  sensitive = true
}
