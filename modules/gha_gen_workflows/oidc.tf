# GitHub Actions OIDC Identity Provider.
#
# AWS requires a thumbprint at creation time, but nowadays this value is
# essentially ignored by the validation (AWS trusts the chain of known
# public CAs directly) — see the note in the official aws-actions/
# configure-aws-credentials action. Instead of hardcoding a value that
# can become stale (which was the cause of the "invalid length" error),
# we fetch the thumbprint dynamically from GitHub's actual certificate
# using the "tls" provider. This removes the risk of a typo and of the
# value expiring when GitHub rotates its certificate.
data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    data.tls_certificate.github_actions.certificates[0].sha1_fingerprint,
  ]

  tags = {
    ManagedBy = "terraform"
    Purpose   = "github-actions-oidc"
  }
}
