# Cross validations: depending on the chosen option, certain buckets are
# mandatory. `validation` in variable does not allow referencing another
# variable, so we use a `check` block (Terraform >= 1.5).

check "rollback_bucket_required" {
  assert {
    condition     = var.workflow_option == "simple-deploy" ? true : var.s3_rollback_bucket_name != null
    error_message = "s3_rollback_bucket_name is required when workflow_option is \"deploy-and-rollback\" or \"deploy-rollback-and-restore\"."
  }
}

check "versions_bucket_required" {
  assert {
    condition     = var.workflow_option == "deploy-rollback-and-restore" ? var.s3_versions_bucket_name != null : true
    error_message = "s3_versions_bucket_name is required when workflow_option is \"deploy-rollback-and-restore\"."
  }
}
