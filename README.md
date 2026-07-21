# Fornax Cutouts — IaC example

Example project showing how to implement mission sources for [fornax-cutouts](https://github.com/dsarmiento/fornax-cutouts)
and deploy them on AWS with Terraform. Use it as a starting point for a new cutout service;
the included example source and infrastructure are not production-hardened.

---

## Repository layout

```text
cutouts/                  # Your mission source package
  sources/
    example.py            # Reference AbstractMissionSource implementation
docker/
  Dockerfile              # Multi-stage image: fornax-cutouts + cutouts/
  entrypoint.sh           # fornax-cutouts CLI entrypoint
terraform/
  main.tf                 # Root module (sandbox + fornax_cutouts)
  deploy.sh               # SSO login + terraform apply with image tag
  variables.tfvars        # Environment-specific values (not committed)
  modules/
    sandbox/              # VPC, IAM, ECR, S3 stage bucket
    fornax_cutouts/       # ECS cluster, ALB, ElastiCache, services
    ecs_service/          # Reusable Fargate service module
tools/
  build_images.sh         # Build and optionally push to ECR
  push_and_deploy.sh      # Build, push, and terraform deploy in one step
docs/
  DEPLOYMENT.md           # Full AWS deployment walkthrough
```

---

## Documentation

| Guide                                          | Description                                             |
| ---------------------------------------------- | ------------------------------------------------------- |
| **[Deployment](docs/DEPLOYMENT.md)**           | Prerequisites, AWS SSO setup, Terraform steps, scripts   |

---

## Quick start (local)

This project uses [uv](https://docs.astral.sh/uv/). Clone [fornax-cutouts](https://github.com/dsarmiento/fornax-cutouts)
next to this repo (`../fornax-cutouts`) for editable local installs.

```bash
uv sync

CUTOUTS__SOURCE_PATH=./cutouts/sources uv run fornax-cutouts --help
```

---

## Deploy to AWS (summary)

Deployments follow this order:

1. **Sandbox prerequisites** — `./terraform/deploy.sh -- -target module.sandbox`
2. **Build and push Docker image** — `./tools/build_images.sh --profile … --push`
3. **Deploy the service** — `./terraform/deploy.sh` or `./tools/push_and_deploy.sh`

For full instructions, configuration options, and troubleshooting, see **[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)**.

Routine updates after initial setup:

```bash
./tools/push_and_deploy.sh --profile your-sso-profile
```

---

## Docker (manual build)

```bash
docker build \
  --platform linux/arm64 \
  -f docker/Dockerfile \
  -t fornax-cutouts-service:latest \
  --build-arg FORNAX_CUTOUTS_REPO_BRANCH=main \
  .

docker run --rm fornax-cutouts-service:latest help
```

The image clones fornax-cutouts from GitHub, installs this project's `cutouts/` package, and sets `CUTOUTS__SOURCE_PATH`
to `/opt/cutouts/cutouts/sources`. See [Container image](docs/DEPLOYMENT.md#container-image) for details.

---

## License

See [LICENSE](LICENSE).
