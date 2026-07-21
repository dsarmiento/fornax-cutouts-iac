# Deployment guide

This guide walks through deploying a [fornax-cutouts](https://github.com/dsarmiento/fornax-cutouts) service on AWS using the Terraform modules and helper scripts in this repository.

The deployment is split into three ordered steps:

1. **Deploy sandbox prerequisites** — VPC, IAM roles, ECR, S3 stage bucket
2. **Build and push the Docker image** — package your mission sources with fornax-cutouts
3. **Deploy the service** — ECS cluster, ALB, ElastiCache, API and worker tasks

After the initial setup, use the [push and deploy scripts](#ongoing-deployments) for routine updates.

---

## Prerequisites

| Tool                                           | Purpose                              |
| ---------------------------------------------- | ------------------------------------ |
| [Terraform](https://www.terraform.io/) >= 1.10 | Infrastructure provisioning          |
| [AWS CLI](https://aws.amazon.com/cli/) v2      | Authentication and ECR login         |
| [Docker](https://www.docker.com/)              | Image builds (ARM64 / `linux/arm64`) |
| [uv](https://docs.astral.sh/uv/)               | Local Python development             |
| AWS SSO profile                                | Access to the target AWS account     |

Clone this repository and, for local development, clone [fornax-cutouts](https://github.com/dsarmiento/fornax-cutouts) as a sibling directory (`../fornax-cutouts`). The Docker build clones fornax-cutouts from GitHub at image build time.

### AWS SSO profile (`~/.aws/config`)

Deployment scripts authenticate with `--profile <name>`. Configure an SSO profile in `~/.aws/config` (create the file if it does not exist).

**1. Define an SSO session** (once per identity provider):

```ini
# ~/.aws/config

[sso-session fornax]
sso_start_url = https://your-org.awsapps.com/start
sso_region    = us-east-1
sso_registration_scopes = sso:account:access
```

Get `sso_start_url` and `sso_region` from your AWS administrator or the IAM Identity Center console.

**2. Add a profile** for each account and role you deploy to:

```ini
[profile fornax-dev]
sso_session    = fornax
sso_account_id = 123456789012
sso_role_name  = AdministratorAccess
region         = us-east-1
output         = json
```

| Setting          | Description                                                         |
| ---------------- | ------------------------------------------------------------------- |
| `sso_session`    | References the `[sso-session …]` block above                        |
| `sso_account_id` | 12-digit AWS account ID                                             |
| `sso_role_name`  | Permission set / role name in IAM Identity Center                   |
| `region`         | Default region for CLI and Terraform (`us-east-1` for this project) |

You can define multiple profiles (for example `fornax-dev`, `fornax-test`) that share the same `sso_session` but use different `sso_account_id` or `sso_role_name` values.

**3. Log in and verify:**

```bash
aws sso login --profile fornax-dev

aws sts get-caller-identity --profile fornax-dev
```

Use the same profile name with Terraform and the helper scripts:

```bash
./tools/build_images.sh --profile fornax-dev --push
./terraform/deploy.sh --profile fornax-dev
./tools/push_and_deploy.sh --profile fornax-dev
```

`deploy.sh` and `push_and_deploy.sh` run `aws sso login` automatically when the session has expired.

> **Note:** SSO profiles do not require entries in `~/.aws/credentials`. Temporary credentials are written to `~/.aws/cli/cache/` after login.

---

## Configuration

### Terraform variables

Copy the example tfvars file and edit it for your environment:

```bash
cp terraform/variables.tfvars.example terraform/variables.tfvars
```

| Variable       | Description                                  | Default          |
| -------------- | -------------------------------------------- | ---------------- |
| `env`          | Short environment name (max 4 chars)         | `dev`            |
| `project_name` | Prefix for AWS resource names (max 16 chars) | `fornax-cutouts` |
| `aws_region`   | AWS region                                   | `us-east-1`      |

The ECR repository created by the sandbox module is named **`{project_name}-service`**. Use the same `project_name` when running `tools/build_images.sh` (via `--project-name`).

### Terraform backend

`terraform/main.tf` uses a **local** backend by default. For team use, replace the `backend "local"` block with your remote backend (for example S3 + DynamoDB) before the first `terraform init`.

### Service configuration

Review `terraform/main.tf` and adjust the `module "fornax_cutouts"` block as needed:

- `network.allowed_ingress_cidr_blocks` — restrict ALB ingress to your IP ranges
- `elasticache.node_type` — Valkey/Redis node size
- `cutouts_service.worker_settings` — Celery concurrency and batch sizes
- `cutouts_service.extra_env_vars` — mission-specific environment variables (see [Mission sources](MISSION_SOURCES.md))

Sandbox module outputs (VPC, subnets, IAM roles, ECR URL, S3 bucket) are wired into the service module automatically.

---

## Step 1: Deploy sandbox prerequisites

The `module.sandbox` provisions shared infrastructure that must exist before ECS can run:

- VPC with public and private subnets
- Internet gateway and NAT routing
- IAM roles (`FornaxCutoutsECSTaskExecutionRole`, backend ECS task role, admin role)
- ECR repository (`{project_name}-service`)
- S3 stage bucket (`{project_name}-{env}-stage`) with lifecycle rules for cutout results

Authenticate with AWS SSO, then apply only the sandbox module:

```bash
./terraform/deploy.sh --profile fornax-dev -- -target=module.sandbox
```

Confirm the outputs include `backend_repo_url`, `vpc_id`, subnet IDs, and `stage_bucket_name`.

> **Using an existing VPC?** Replace the `network` block in `main.tf` with your own `vpc_id`, `public_subnet_ids`, and `private_subnet_ids`, and skip or partially apply the sandbox networking resources. You still need the sandbox IAM roles, ECR repo, and S3 bucket (or equivalent resources you manage separately).

---

## Step 2: Build and push the Docker image

ECS tasks pull the service image from ECR. Build the image from the repository root.

### What the image contains

See [Container image](#container-image) below for Dockerfile details. In short:

- **fornax-cutouts** is cloned from GitHub during the build
- Your mission sources under `cutouts/` are copied into the image
- `CUTOUTS__SOURCE_PATH` points at `/opt/cutouts/cutouts/sources`

### Build and push to ECR

Use the helper script (recommended):

```bash
./tools/build_images.sh --profile fornax-dev --push
```

| Flag             | Description                                                     |
| ---------------- | --------------------------------------------------------------- |
| `--profile`      | AWS CLI profile (required)                                      |
| `--push`         | Log in to ECR and push after build                              |
| `--project-name` | Must match Terraform `project_name` (default: `fornax-cutouts`) |
| `--branch`       | fornax-cutouts git branch to clone in the Dockerfile            |
| `--tag`          | Image tag in ECR (default: `latest`)                            |
| `--no-cache`     | Force a clean Docker build                                      |

The image is tagged as `{account}.dkr.ecr.us-east-1.amazonaws.com/{project_name}-service:{tag}`.

**Important:** Push an image before Step 3. ECS task definitions reference `backend_repo_url:image_tag`; if the tag does not exist, tasks will fail to start.

### Build locally (no push)

```bash
docker build \
  --platform linux/arm64 \
  -f docker/Dockerfile \
  -t fornax-cutouts-service:latest \
  --build-arg FORNAX_CUTOUTS_REPO_BRANCH=main \
  .

docker run --rm fornax-cutouts-service:latest help
```

---

## Step 3: Deploy the service

Apply the full stack (or only the service module if sandbox is already up):

```bash
./terraform/deploy --profile fornax-dev
```

### What gets created

`module.fornax_cutouts` provisions:

| Resource                  | Purpose                                              |
| ------------------------- | ---------------------------------------------------- |
| ECS Fargate cluster       | Runs API and worker tasks (ARM64)                    |
| Application Load Balancer | Public HTTP(S) endpoint for the API                  |
| ElastiCache (Valkey)      | Redis for UWS job state and Celery broker            |
| ECS services              | `backend` (API), `cutouts_worker`, `high_mem_worker` |
| Security groups           | ALB ↔ ECS ↔ cache                                    |

After apply, verify the API health endpoint:

```bash
curl "http://$(terraform output -state=./terraform/terraform.tfstate -raw alb_dns_name)/api/health"
```

(Optional) Set `network.acm_certificate_arn` in `main.tf` to enable HTTPS on the ALB.

---

## Ongoing deployments

For day-to-day code changes, use the automation scripts instead of running each step manually.

### `tools/build_images.sh`

Builds the Docker image and optionally pushes to ECR. Use when you only need a new image without redeploying Terraform.

```bash
./tools/build_images.sh --profile fornax-dev --push --tag main.abc1234
```

### `terraform/deploy.sh`

Runs `terraform apply` with SSO login, `variables.tfvars`, and an image tag:

```bash
./terraform/deploy.sh --profile fornax-dev --tag main.abc1234
```

Pass extra Terraform arguments after `--`:

```bash
./terraform/deploy.sh --profile fornax-dev --tag main.abc1234 -- \
  -target=module.fornax_cutouts -auto-approve
```

### `tools/push_and_deploy.sh`

End-to-end workflow: build with `--no-cache`, push to ECR, then deploy. The image tag is **`{git-branch}.{short-sha}`** from this repository.

```bash
./tools/push_and_deploy.sh \
  --profile fornax-dev \
  --project-name fornax-cutouts \
  --branch main
```

| Flag             | Description                                                  |
| ---------------- | ------------------------------------------------------------ |
| `--profile`      | AWS CLI profile (required)                                   |
| `--branch`       | fornax-cutouts branch for the Docker build (default: `main`) |
| `--project-name` | ECR repo prefix; must match Terraform `project_name`         |

This is the usual command after changing mission source code or dependencies in `cutouts/`.

---

## Container image

### Dockerfile (`docker/Dockerfile`)

Multi-stage build:

1. **Builder** (`ghcr.io/astral-sh/uv:python3.13-trixie`)
   - Clones fornax-cutouts from GitHub (`FORNAX_CUTOUTS_REPO_ORG`, `FORNAX_CUTOUTS_REPO_BRANCH`)
   - Installs dependencies from `pyproject.toml` / `uv.lock`
   - Copies `cutouts/` into `/opt/cutouts/cutouts/`

2. **Runtime** (`python:3.13-trixie`)
   - Non-root user `cutouts` (uid/gid 999)
   - Virtualenv at `/opt/cutouts/.venv`
   - `CUTOUTS__SOURCE_PATH=/opt/cutouts/cutouts/sources`

Build args:

| Arg                          | Default      | Description                        |
| ---------------------------- | ------------ | ---------------------------------- |
| `FORNAX_CUTOUTS_REPO_ORG`    | `dsarmiento` | GitHub org/user for fornax-cutouts |
| `FORNAX_CUTOUTS_REPO_BRANCH` | `main`       | Branch to clone                    |

### Entrypoint (`docker/entrypoint.sh`)

Delegates to the `fornax-cutouts` CLI. ECS task definitions override the default `help` command:

| Command                            | ECS service                      |
| ---------------------------------- | -------------------------------- |
| `api`                              | `backend` — FastAPI on port 8000 |
| `worker --queues cutouts`          | `cutouts_worker`                 |
| `worker --queues high_mem,cutouts` | `high_mem_worker`                |

Environment variables for Redis, S3 storage prefix, logging, and workers are set in `terraform/modules/fornax_cutouts/services.tf`.

---

## Troubleshooting

| Symptom                                        | Check                                                                                      |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------ |
| ECS tasks fail with `CannotPullContainerError` | Image tag exists in ECR; `image_tag` matches the pushed tag                                |
| API returns unknown mission                    | Mission module is under `cutouts/sources/`; `CUTOUTS__SOURCE_PATH` is correct in the image |
| Workers cannot reach Redis                     | Security groups allow ECS → ElastiCache; `CUTOUTS__REDIS__*` env vars                      |
| Cutouts fail S3 access                         | Task role policy includes stage bucket; `CUTOUTS__STORAGE__PREFIX` matches bucket          |

CloudWatch log groups: `/{project_name}/{env}/ecs/{service_name}` (for example `/fornax-cutouts/dev/ecs/backend`).
