# Fornax Cutouts - IaC Example

> **Work in progress.** This is a barebones example project demonstrating how to implement a mission source for [fornax-cutouts](https://github.com/dsarmiento/fornax-cutouts) and deploy it on AWS using the provided Terraform modules. Neither the example source nor the IaC are production-ready.

---

## Repository layout

```text
cutouts/           # Example mission source package
  sources/
    example.py     # ExampleSource implementation
docker/            # Dockerfile and entrypoint for the service
terraform/         # Terraform configuration
  main.tf          # Root module with inline placeholder values
  modules/
    ecs_service/   # Reusable ECS service module
    fornax_cutouts/# Top-level module (ECS cluster, ALB, Elasticache, workers)
```

---

## Example source

`cutouts/sources/example.py` contains a minimal `ExampleSource` that:

- Registers itself with the `cutout_registry` via `@cutout_registry.register_source()`.
- Implements `validate_request` and `get_filenames`.
- Uses a placeholder filename template — no real data access is performed.

It is intended as a starting point; the `get_filenames` logic, metadata values, and any mission-specific parameters all need to be replaced with real implementations.

---

## Running the example

The project uses [uv](https://docs.astral.sh/uv/) for dependency management. `fornax-cutouts` is currently not published to PyPI, so it is expected to be checked out as a sibling directory (`../fornax-cutouts`).

```bash
# Install dependencies (creates .venv automatically)
uv sync

# Run the fornax-cutouts CLI with the example source loaded
uv run fornax-cutouts --help
```

Set `CUTOUTS__SOURCE_PATH` to the directory containing your source modules if it differs from the default:

```bash
CUTOUTS__SOURCE_PATH=./cutouts/sources uv run fornax-cutouts --help
```

---

## Docker

```bash
docker build \
  --build-arg FORNAX_CUTOUTS_REPO_ORG=dsarmiento \
  --build-arg FORNAX_CUTOUTS_REPO_BRANCH=main \
  -t fornax-cutouts-example \
  -f docker/Dockerfile .

docker run --rm fornax-cutouts-example help
```

The image clones `fornax-cutouts` from GitHub at build time because the package is not yet on PyPI.

---

## Terraform / IaC

> **Semi-functional.** The Terraform modules provision the core AWS infrastructure (ECS cluster, Fargate services, ALB, Elasticache), but several resources are expected to be pre-provisioned outside of this repository as part of the broader deployment process. Applying without those prerequisites will fail.

### Pre-provisioned prerequisites

The following must exist before running `terraform apply`:

| Resource                               | Notes                                                 |
| -------------------------------------- | ----------------------------------------------------- |
| VPC, public/private subnets            | Set in `network` block in `main.tf`                   |
| ACM certificate                        | Optional; required for HTTPS on the ALB               |
| Route53 hosted zone                    | Optional; required for DNS record creation            |
| IAM role `CutoutsBackendECSTaskRole`   | Task role for the cutouts service                     |
| IAM role `CutoutsECSTaskExecutionRole` | ECS task execution role                               |
| ECR repository / image                 | `image_url` in `main.tf` must point to a pushed image |

### Apply

Update the placeholder values in `terraform/main.tf` (marked with `# TODO`), then:

```bash
cd terraform
terraform init
terraform apply
```
