# ==============================================================================
# Render, using templatefile(), the set of workflows corresponding to
# var.workflow_option, writing the files in .github/workflows.
# ==============================================================================

locals {
  # Base map of variables common to almost all templates.
  # Each resource below uses merge() to add what is specific.
  base_template_vars = {
    role_arn                   = aws_iam_role.github_actions_deploy.arn
    aws_region                 = var.aws_region
    deploy_branch              = var.deploy_branch
    build_command              = var.build_command
    build_output_dir           = var.build_output_dir
    s3_main_bucket_name        = var.s3_main_bucket_name
    s3_rollback_bucket_name    = var.s3_rollback_bucket_name
    s3_versions_bucket_name    = var.s3_versions_bucket_name
    ssm_parameter_name         = var.ssm_parameter_name
    cloudfront_distribution_id = var.cloudfront_distribution_id
  }
}

# ------------------------------------------------------------------------------
# Option 1: simple-deploy -> only deploy.yml
# ------------------------------------------------------------------------------
resource "local_file" "simple_deploy" {
  count = var.generate_workflows && var.workflow_option == "simple-deploy" ? 1 : 0

  filename = "${var.workflows_output_path}/deploy.yml"
  content = templatefile(
    "${path.module}/templates/simple-deploy.yml.tpl",
    local.base_template_vars
  )
  file_permission = "0644"
}

# ------------------------------------------------------------------------------
# Option 2: deploy-and-rollback -> deploy.yml + rollback.yml
# ------------------------------------------------------------------------------
resource "local_file" "deploy_with_rollback_backup" {
  count = var.generate_workflows && var.workflow_option == "deploy-and-rollback" ? 1 : 0

  filename = "${var.workflows_output_path}/deploy.yml"
  content = templatefile(
    "${path.module}/templates/deploy-with-rollback-backup.yml.tpl",
    local.base_template_vars
  )
  file_permission = "0644"
}

resource "local_file" "rollback_toggle" {
  count = var.generate_workflows && var.workflow_option == "deploy-and-rollback" ? 1 : 0

  filename = "${var.workflows_output_path}/rollback.yml"
  content = templatefile(
    "${path.module}/templates/rollback-toggle.yml.tpl",
    local.base_template_vars
  )
  file_permission = "0644"
}

# ------------------------------------------------------------------------------
# Option 3: deploy-rollback-and-restore -> deploy.yml + rollback-and-restore.yml
# ------------------------------------------------------------------------------
resource "local_file" "deploy_with_versioning" {
  count = var.generate_workflows && var.workflow_option == "deploy-rollback-and-restore" ? 1 : 0

  filename = "${var.workflows_output_path}/deploy.yml"
  content = templatefile(
    "${path.module}/templates/deploy-with-versioning.yml.tpl",
    local.base_template_vars
  )
  file_permission = "0644"
}

resource "local_file" "rollback_and_restore" {
  count = var.generate_workflows && var.workflow_option == "deploy-rollback-and-restore" ? 1 : 0

  filename = "${var.workflows_output_path}/rollback-and-restore.yml"
  content = templatefile(
    "${path.module}/templates/rollback-and-restore.yml.tpl",
    local.base_template_vars
  )
  file_permission = "0644"
}
