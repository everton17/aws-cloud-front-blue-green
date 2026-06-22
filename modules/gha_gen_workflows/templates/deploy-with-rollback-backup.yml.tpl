name: Deploy

on:
  push:
    branches: [${deploy_branch}]
  workflow_dispatch:

permissions:
  id-token: write   # required for OIDC authentication
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${role_arn}
          aws-region: ${aws_region}
          role-session-name: gha-deploy-$${{ github.run_id }}

      - name: Clear rollback bucket
        run: |
          aws s3 rm s3://${s3_rollback_bucket_name} --recursive

      - name: Copy current version from main bucket to rollback bucket
        run: |
          aws s3 sync s3://${s3_main_bucket_name} s3://${s3_rollback_bucket_name}

      - name: Build
        run: |
          ${build_command}

      - name: Upload new version to main bucket
        run: |
          aws s3 sync ${build_output_dir} s3://${s3_main_bucket_name} --delete

      - name: Ensure rollback parameter store is set to false
        run: |
          CURRENT_VALUE=$(aws ssm get-parameter \
            --name "${ssm_parameter_name}" \
            --query "Parameter.Value" \
            --output text 2>/dev/null || echo "false")

          if [ "$CURRENT_VALUE" = "true" ]; then
            echo "Parameter store is true, changing to false"
            aws ssm put-parameter \
              --name "${ssm_parameter_name}" \
              --value "false" \
              --type String \
              --overwrite
          else
            echo "Parameter store is already false, nothing to do"
          fi

      - name: Invalidate CloudFront cache
        id: invalidate
        run: |
          INVALIDATION_ID=$(aws cloudfront create-invalidation \
            --distribution-id ${cloudfront_distribution_id} \
            --paths "/*" \
            --query "Invalidation.Id" \
            --output text)
          echo "invalidation_id=$INVALIDATION_ID" >> "$GITHUB_OUTPUT"

      - name: Check invalidation status
        run: |
          aws cloudfront wait invalidation-completed \
            --distribution-id ${cloudfront_distribution_id} \
            --id $${{ steps.invalidate.outputs.invalidation_id }}

          STATUS=$(aws cloudfront get-invalidation \
            --distribution-id ${cloudfront_distribution_id} \
            --id $${{ steps.invalidate.outputs.invalidation_id }} \
            --query "Invalidation.Status" \
            --output text)

          if [ "$STATUS" = "Completed" ]; then
            echo "Invalidation executed successfully (ID: $${{ steps.invalidate.outputs.invalidation_id }})"
          else
            echo "Invalidation finished with unexpected status: $STATUS"
            exit 1
          fi
