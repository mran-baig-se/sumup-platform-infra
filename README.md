# SumUp Platform Infra

Self-service AWS resource provisioning for engineering teams. Each team declares what they need in a YAML file. The platform provisions it, keeps it secure, and maintains isolated state per team.

## Architecture

```
teams/
├── team-alpha.yaml   ← team owns this file
├── team-beta.yaml
└── team-gamma.yaml
        │
        ▼ (CI detects changed file via git diff)
.github/workflows/apply-changes.yml
        │
        ▼ (runs terraform per team with isolated state key)
platform/main.tf  →  modules/team-resources/
        │                   ├── S3 buckets (with public access enforcement)
        │                   └── IAM role (scoped to team's buckets only)
        ▼
S3 state bucket
  teams/team-alpha/terraform.tfstate   ← isolated per team
  teams/team-beta/terraform.tfstate
```

### Why separate state files, not workspaces?

Terraform workspaces share a backend configuration. A misconfiguration or bug in one team's state operation can affect others. Separate S3 keys give true blast radius isolation: one team's state corruption is fully contained. It also makes team offboarding clean — destroy the state file along with the resources.

## Onboarding a new team

1. Create `teams/your-team-name.yaml`:

```yaml
team_name: your-team-name
buckets:
  - name: data
    visibility: private        # explicit — no defaults
  - name: public-assets
    visibility: public
```

2. Open a pull request. CI validates the YAML schema, lints Terraform, runs Checkov security scan.

3. Merge to `main`. CI detects the new file and provisions your resources automatically.

That's it. Zero changes to platform code required.

## Security design

- **IAM least privilege**: each team's IAM role has an explicit policy scoped to only its own bucket ARNs. No wildcard resources.
- **Explicit deny**: the policy also contains an explicit `s3:*` deny on all buckets NOT owned by the team.
- **Visibility enforcement**: `public` and `private` are the only valid values. No defaults. Validated at plan time.
- **Public bucket handling**: public buckets still get a controlled `aws_s3_bucket_public_access_block` — ACL-level public access is blocked, only bucket policy can grant access.
- **Encryption**: all buckets use AES-256 server-side encryption.
- **Versioning**: all buckets have versioning enabled.

## Testing without an AWS account

### Option 1 — Static analysis (no Docker needed)

```bash
# Install tools
pip install checkov
brew install tflint  # or: curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# Validate
terraform -chdir=./modules/team-resources init -backend=false
terraform -chdir=./modules/team-resources validate
terraform fmt -check -recursive

# Lint
tflint --recursive

# Security scan
checkov -d modules/ --framework terraform
```

### Option 2 — Full integration test with LocalStack (fake AWS, local Docker)

```bash
# One-time setup
pip install localstack terraform-local awscli-local
docker pull localstack/localstack

# Run the test script
chmod +x ./tests/test-localstack.sh
./tests/test-localstack.sh
```

This actually creates S3 buckets and IAM roles, verifies public access blocks, and checks there are no wildcard IAM resources — all without any AWS account.

## CI/CD (GitHub Actions — free for public repos)

| Workflow | Trigger | What it does |
|---|---|---|
| `validate.yml` | Every PR touching teams/ or modules/ | fmt check, validate, tflint, checkov, YAML schema validation |
| `test-localstack.yml` | Every PR touching modules/ or platform/ | Full apply + resource verification against LocalStack |
| `apply-changes.yml` | Push to main, only changed team files | Detects changed YAMLs via `git diff`, applies each in parallel with isolated state |

## Team offboarding

Delete the team's YAML file and merge to main. CI detects the deletion, restores the config from git history, runs `terraform destroy` for that team only, and removes its state file. Resources are gone; no other team is affected.

## Tagging strategy

All resources are tagged with:
- `Team` — for cost allocation per team
- `CostCenter` — same as team name, used in billing dashboards
- `Environment` — prod/staging/dev
- `ManagedBy` — terraform
- `Repo` — this repository
- `Visibility` — public/private (on buckets, for audit)

## Local development

```bash
# Apply one team locally (against LocalStack)
export AWS_DEFAULT_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test

docker run -d -p 4566:4566 -e SERVICES=s3,iam,sts localstack/localstack
awslocal s3 mb s3://tfstate-local

./scripts/apply-team.sh team-alpha plan
```
