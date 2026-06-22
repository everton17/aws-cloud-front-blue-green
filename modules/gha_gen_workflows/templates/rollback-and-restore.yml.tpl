name: Rollback and Restore

on:
  workflow_dispatch:
    inputs:
      restore_version:
        description: "Check to restore a specific version (instead of just toggling the rollback)"
        required: false
        type: boolean
        default: false
      commit_hash:
        description: "Commit hash of the version to restore (required if restore_version is checked)"
        required: false
        type: string

permissions:
  id-token: write   # required for OIDC authentication
  contents: read

jobs:
  validate-inputs:
    runs-on: ubuntu-latest
    steps:
      - name: Validate input combination
        run: |
          if [ "$${{ inputs.restore_version }}" = "true" ] && [ -z "$${{ inputs.commit_hash }}" ]; then
            echo "::error::commit_hash is required when restore_version is checked."
            exit 1
          fi

  # ----------------------------------------------------------------------
  # Path 1: only toggles the rollback parameter store (without restore)
  # ----------------------------------------------------------------------
  rollback-toggle:
    needs: validate-inputs
    if: $${{ inputs.restore_version == false }}
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

  # ----------------------------------------------------------------------
  # Path 2: restores a specific version from the versions bucket
  # ----------------------------------------------------------------------
  restore-specific-version:
    needs: validate-inputs
    if: $${{ inputs.restore_version == true }}
    runs-on: ubuntu-latest
    steps:
      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${role_arn}
          aws-region: ${aws_region}
          role-session-name: gha-restore-$${{ github.run_id }}

      - name: Check if the version exists in the versions bucket
        id: check_version
        run: |
          PACKAGE_NAME="$${{ inputs.commit_hash }}.tar.gz"

          if ! aws s3api head-object \
            --bucket ${s3_versions_bucket_name} \
            --key "$PACKAGE_NAME" 2>/dev/null; then
            echo "::error::The requested version does not exist, please check the commit hash and re-run the workflow"
            exit 1
          fi

          echo "package_name=$PACKAGE_NAME" >> "$GITHUB_OUTPUT"

      - name: Download and extract the requested version
        run: |
          mkdir -p ./restore
          aws s3 cp \
            s3://${s3_versions_bucket_name}/$${{ steps.check_version.outputs.package_name }} \
            ./restore/$${{ steps.check_version.outputs.package_name }}

          tar -xzf ./restore/$${{ steps.check_version.outputs.package_name }} -C ./restore

      - name: Empty the main bucket
        run: |
          aws s3 rm s3://${s3_main_bucket_name} --recursive

      - name: Upload restored files to the main bucket
        run: |
          # Remove the downloaded .tar.gz before syncing to avoid uploading the package itself
          rm -f ./restore/$${{ steps.check_version.outputs.package_name }}
          aws s3 sync ./restore s3://${s3_main_bucket_name}

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
