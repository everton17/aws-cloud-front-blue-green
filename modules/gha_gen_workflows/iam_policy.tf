locals {
  # build a list of active buckets, based on the workflow option. The list will not contain
  # nulls (rollback/versions only included when the option requires).
  active_bucket_names = compact([
    var.s3_main_bucket_name,
    var.s3_rollback_bucket_name,
    var.workflow_option == "deploy-rollback-and-restore" ? var.s3_versions_bucket_name : null,
  ])
}

data "aws_iam_policy_document" "github_actions_deploy" {

  # --- S3: upload and delete restricted to active buckets (main, rollback and, if applicable, versions) ---
  statement {
    sid    = "S3DeployBucketLevel"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [for name in local.active_bucket_names : "arn:aws:s3:::${name}"]
  }

  statement {
    sid    = "S3DeployObjectLevel"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
    ]
    resources = [for name in local.active_bucket_names : "arn:aws:s3:::${name}/*"]
  }

  # --- SSM Parameter Store: write restricted to a specific parameter ---
  statement {
    sid    = "SSMWriteSpecificParameter"
    effect = "Allow"
    actions = [
      "ssm:PutParameter",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:LabelParameterVersion",
    ]
    resources = [var.ssm_parameter_arn]
  }

  # --- CloudFront: only allow creating invalidation on the specified distribution ---
  statement {
    sid    = "CloudFrontInvalidation"
    effect = "Allow"
    actions = [
      "cloudfront:CreateInvalidation",
      "cloudfront:GetInvalidation",
      "cloudfront:ListInvalidations",
    ]
    resources = [var.cloudfront_distribution_arn]
  }
}

resource "aws_iam_policy" "github_actions_deploy" {
  name        = "${var.role_name}-policy"
  description = "Minimum permissions for deploy via GitHub Actions (option: ${var.workflow_option})"
  policy      = data.aws_iam_policy_document.github_actions_deploy.json
}

resource "aws_iam_role_policy_attachment" "github_actions_deploy" {
  role       = aws_iam_role.github_actions_deploy.name
  policy_arn = aws_iam_policy.github_actions_deploy.arn
}
