module "gha_gen_workflows" {
  source = "./modules/gha_gen_workflows"

  count = var.gha_gen_workflows.generate_workflows ? 1 : 0

  generate_workflows          = var.gha_gen_workflows.generate_workflows
  github_org                  = var.gha_gen_workflows.github_org
  github_repo                 = var.gha_gen_workflows.github_repo
  role_name                   = var.gha_gen_workflows.role_name
  aws_account_id              = data.aws_caller_identity.current.account_id
  workflow_option             = var.gha_gen_workflows.workflow_option
  s3_main_bucket_name         = aws_s3_bucket.this[values(local.production_bucket)[0].name].id
  s3_rollback_bucket_name     = length(local.rollback_bucket) > 0 ? aws_s3_bucket.this[values(local.rollback_bucket)[0].name].id : ""
  s3_versions_bucket_name     = length(local.versioning_buckets) > 0 ? aws_s3_bucket.this[values(local.versioning_buckets)[0].name].id : ""
  ssm_parameter_arn           = length(aws_ssm_parameter.rollback) > 0 ? aws_ssm_parameter.rollback[0].arn : ""
  cloudfront_distribution_arn = aws_cloudfront_distribution.this.arn
  aws_region                  = var.region
  deploy_branch               = var.gha_gen_workflows.deploy_branch
  build_command               = var.gha_gen_workflows.build_command
  build_output_dir            = var.gha_gen_workflows.build_output_dir
  ssm_parameter_name          = length(aws_ssm_parameter.rollback) > 0 ? aws_ssm_parameter.rollback[0].name : ""
  cloudfront_distribution_id  = aws_cloudfront_distribution.this.id
  workflows_output_path       = var.gha_gen_workflows.workflows_output_path

}
