#!/usr/bin/env bash
# Usage: ./scripts/apply-team.sh <team-name> [plan|apply|destroy]
# Example: ./scripts/apply-team.sh team-alpha apply
#
# This script is called by CI for each changed team file.
# It initialises Terraform with an isolated backend key per team,
# then runs plan or apply. State isolation is enforced here — each
# team gets its own key in the S3 state bucket.

set -euo pipefail

TEAM="${1:?Usage: $0 <team-name> [plan|apply|destroy]}"
ACTION="${2:-plan}"
ENVIRONMENT="${ENVIRONMENT:-prod}"
TFSTATE_BUCKET="${TFSTATE_BUCKET:-company-tfstate}"
AWS_REGION="${AWS_REGION:-eu-west-1}"

TEAM_CONFIG="teams/${TEAM}.yaml"
STATE_KEY="teams/${TEAM}/terraform.tfstate"

if [[ ! -f "${TEAM_CONFIG}" ]]; then
  echo "ERROR: Team config not found: ${TEAM_CONFIG}"
  exit 1
fi

echo "==> Initialising Terraform for team: ${TEAM}"
echo "    State key: ${STATE_KEY}"

terraform -chdir=./platform init -reconfigure \
  -backend-config="bucket=${TFSTATE_BUCKET}" \
  -backend-config="key=${STATE_KEY}" \
  -backend-config="region=${AWS_REGION}" \
  -backend-config="encrypt=true"

case "${ACTION}" in
  plan)
    echo "==> Planning resources for team: ${TEAM}"
    terraform -chdir=./platform plan \
      -var="team_config_file=../${TEAM_CONFIG}" \
      -var="environment=${ENVIRONMENT}"
    ;;
  apply)
    echo "==> Applying resources for team: ${TEAM}"
    terraform -chdir=./platform apply \
      -var="team_config_file=../${TEAM_CONFIG}" \
      -var="environment=${ENVIRONMENT}" \
      -auto-approve
    ;;
  destroy)
    echo "==> DESTROYING resources for team: ${TEAM}"
    echo "    This action is irreversible. Sleeping 10s for safety..."
    sleep 10
    terraform -chdir=./platform destroy \
      -var="team_config_file=../${TEAM_CONFIG}" \
      -var="environment=${ENVIRONMENT}" \
      -auto-approve
    ;;
  *)
    echo "ERROR: Unknown action '${ACTION}'. Use plan, apply, or destroy."
    exit 1
    ;;
esac
