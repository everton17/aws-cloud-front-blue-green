output "github_actions_role_arn" {
  description = "ARN of the role to be used in the workflow (role-to-assume)"
  value       = aws_iam_role.github_actions_deploy.arn
}

output "github_actions_oidc_provider_arn" {
  description = "ARN of the created OIDC provider (to be used in the trust policy of the role)"
  value       = aws_iam_openid_connect_provider.github_actions.arn
}

output "github_actions_policy_arn" {
  description = "ARN of the deploy policy attached to the role"
  value       = aws_iam_policy.github_actions_deploy.arn
}

output "generated_workflow_files" {
  description = "Paths of the generated workflow files, according to var.workflow_option"
  value = compact(concat(
    var.generate_workflows && var.workflow_option == "simple-deploy" ? [
      local_file.simple_deploy[0].filename
    ] : [],
    var.generate_workflows && var.workflow_option == "deploy-and-rollback" ? [
      local_file.deploy_with_rollback_backup[0].filename,
      local_file.rollback_toggle[0].filename,
    ] : [],
    var.generate_workflows && var.workflow_option == "deploy-rollback-and-restore" ? [
      local_file.deploy_with_versioning[0].filename,
      local_file.rollback_and_restore[0].filename,
    ] : [],
  ))
}
