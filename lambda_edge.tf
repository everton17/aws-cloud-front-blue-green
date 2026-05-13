data "aws_caller_identity" "current" {}

# Generate zip to lambda@edge from template file
data "archive_file" "lambda_zip" {
  count       = var.lambda_edge.enabled ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/.terraform/lambda_edge.zip"

  source {
    content = templatefile("${path.module}/lambda/index.js.tpl", {
      parameter_name  = aws_ssm_parameter.rollback[count.index].name
      old_site_domain = aws_s3_bucket_website_configuration.this[values(local.rollback_bucket)[count.index].name].website_endpoint
      new_site_domain = aws_s3_bucket_website_configuration.this[values(local.production_bucket)[count.index].name].website_endpoint
    })
    filename = "index.js"
  }
}

# IAM Role
resource "aws_iam_role" "lambda_edge" {
  count = var.lambda_edge.enabled ? 1 : 0

  name = "lambda-edge-rollback-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = [
          "lambda.amazonaws.com",
          "edgelambda.amazonaws.com"
        ]
      }
      Action = "sts:AssumeRole"
    }]
  })
}



resource "aws_iam_role_policy" "lambda_edge_ssm" {
  count = var.lambda_edge.enabled ? 1 : 0

  name = "lambda-edge-ssm-policy"
  role = aws_iam_role.lambda_edge[count.index].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ssm:GetParameter"
        Resource = aws_ssm_parameter.rollback[count.index].arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        # Lambda@Edge send logs to CloudWatch Logs in the us-east-1 region.
        Resource = "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/us-east-1.${aws_lambda_function.edge_rollback[count.index].function_name}:*"
      }
    ]
  })
}

resource "aws_lambda_function" "edge_rollback" {
  count = var.lambda_edge.enabled ? 1 : 0

  filename         = data.archive_file.lambda_zip[count.index].output_path
  source_code_hash = data.archive_file.lambda_zip[count.index].output_base64sha256
  function_name    = var.lambda_edge.function_name
  role             = aws_iam_role.lambda_edge[count.index].arn
  handler          = var.lambda_edge.handler
  runtime          = var.lambda_edge.runtime
  publish          = true

  lifecycle {
    create_before_destroy = true
  }
}

# SSM Parameter
resource "aws_ssm_parameter" "rollback" {
  count = var.lambda_edge.enabled ? 1 : 0

  name  = var.lambda_edge.parameter_store_name
  type  = "String"
  value = "false"

  lifecycle {
    ignore_changes = [value] # evict changes to the parameter value to avoid unnecessary updates to the Lambda function
  }
}
