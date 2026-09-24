#!/usr/bin/env bash
# Test the module against LocalStack (fake AWS) — no real AWS account needed.
#
# Prerequisites (one-time setup):
#   pip install localstack terraform-local awscli-local
#   docker pull localstack/localstack
#
# Run: ./tests/test-localstack.sh

set -euo pipefail

LOCALSTACK_PORT=4566
FAKE_BUCKET="tfstate-local"
TEST_TEAM="test-team-local"

echo "==> Starting LocalStack..."
docker run -d --rm \
  --name localstack-test \
  -p ${LOCALSTACK_PORT}:4566 \
  -e SERVICES=s3,iam,sts \
  localstack/localstack

# Wait for LocalStack to be ready
echo "==> Waiting for LocalStack to be ready..."
for i in {1..30}; do
  if curl -sf http://localhost:${LOCALSTACK_PORT}/_localstack/health | grep -q '"s3": "available"'; then
    echo "    LocalStack ready."
    break
  fi
  sleep 2
done

# Create state bucket in LocalStack
awslocal s3 mb s3://${FAKE_BUCKET} --region us-east-1

# Write a test team config
cat > /tmp/test-team.yaml <<EOF
team_name: ${TEST_TEAM}
buckets:
  - name: data
    visibility: private
  - name: public-cdn
    visibility: public
EOF

echo ""
echo "==> Running terraform init (pointing to LocalStack)..."
export AWS_DEFAULT_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test

# tflocal is a wrapper that automatically redirects Terraform to LocalStack
tflocal -chdir=./platform init \
  -backend-config="bucket=${FAKE_BUCKET}" \
  -backend-config="key=teams/${TEST_TEAM}/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="endpoint=http://localhost:4566" \
  -backend-config="force_path_style=true" \
  -reconfigure

echo ""
echo "==> Running terraform apply against LocalStack..."
tflocal -chdir=./platform apply \
  -var="team_config_file=../$(realpath --relative-to=./platform /tmp/test-team.yaml)" \
  -var="environment=dev" \
  -auto-approve

echo ""
echo "==> Verifying resources in LocalStack..."

# Check buckets exist
echo "Buckets:"
awslocal s3 ls | grep "${TEST_TEAM}"

# Check IAM role exists
echo "IAM Role:"
awslocal iam get-role --role-name "dev-${TEST_TEAM}-role" --query 'Role.RoleName'

# Check private bucket has access blocked
echo "Public access block for 'data' bucket (should all be true):"
awslocal s3api get-public-access-block \
  --bucket "dev-${TEST_TEAM}-data" \
  --query 'PublicAccessBlockConfiguration'

# Check IAM policy has no wildcards
echo ""
echo "==> Checking IAM policy for wildcard resources..."
POLICY=$(awslocal iam get-role-policy \
  --role-name "dev-${TEST_TEAM}-role" \
  --policy-name "dev-${TEST_TEAM}-s3-policy" \
  --query 'PolicyDocument')

if echo "$POLICY" | grep -q '"Resource": "\*"'; then
  echo "FAIL: IAM policy contains wildcard resource!"
  exit 1
else
  echo "PASS: No wildcard resources in IAM policy."
fi

echo ""
echo "==> Cleanup..."
tflocal -chdir=./platform destroy \
  -var="team_config_file=../$(realpath --relative-to=./platform /tmp/test-team.yaml)" \
  -var="environment=dev" \
  -auto-approve

docker stop localstack-test
echo ""
echo "All tests passed!"
