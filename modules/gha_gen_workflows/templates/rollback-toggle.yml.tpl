name: Rollback

on:
  workflow_dispatch:

permissions:
  id-token: write   # required for OIDC authentication
  contents: read

jobs:
  rollback:
    runs-on: ubuntu-latest
    steps:
      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${role_arn}
          aws-region: ${aws_region}
          role-session-name: gha-rollback-$${{ github.run_id }}

      - name: Activate rollback in parameter store
        run: |
          CURRENT_VALUE=$(aws ssm get-parameter \
            --name "${ssm_parameter_name}" \
            --query "Parameter.Value" \
            --output text 2>/dev/null || echo "false")

          if [ "$CURRENT_VALUE" = "false" ]; then
            echo "Parameter store is false, changing to true"
            aws ssm put-parameter \
              --name "${ssm_parameter_name}" \
              --value "true" \
              --type String \
              --overwrite
          else
            echo "Parameter store is already true, nothing to do"
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
