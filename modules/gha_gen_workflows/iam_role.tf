# Trust policy: set who can assume the role. In this case, only GitHub Actions from the specified repository.
# Restricted to the specified repository (any branch, tag, or pull_request)
# — not to any repository in the organization.
data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    sid     = "AllowGitHubActionsOIDC"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # repo:ORG/REPO:* covers any branch, tag, environment, or pull_request
    # from this specific repository.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions_deploy" {
  name                 = var.role_name
  assume_role_policy   = data.aws_iam_policy_document.github_actions_trust.json
  max_session_duration = 3600 # 1h — adjust if deploys take longer

  tags = {
    ManagedBy = "terraform"
    Purpose   = "github-actions-deploy"
  }
}
