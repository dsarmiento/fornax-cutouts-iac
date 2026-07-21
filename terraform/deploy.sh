#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<EOF
Usage: $0 --profile <AWS_PROFILE> [--tag TAG] [--help] [-- <extra terraform args>]

Authenticates via AWS SSO and runs terraform apply for the given environment.

Arguments:
  --profile <AWS_PROFILE> AWS profile to use

Options:
  -t, --tag TAG   Docker image tag to deploy (default: latest)
                  Format: <branch>.<short-sha>  e.g. main.abc1234
  -h, --help      Show this help message and exit
  --              Pass remaining arguments directly to terraform apply

Examples:
  $0 --profile <AWS_PROFILE>
  $0 --profile <AWS_PROFILE> --tag main.abc1234
  $0 --profile <AWS_PROFILE> -- -target=module.fornax_cutouts
  $0 --profile <AWS_PROFILE> --tag main.abc1234 -- -target=module.fornax_cutouts -auto-approve
EOF
}

if [[ $# -lt 1 || "$1" == "--help" || "$1" == "-h" ]]; then
    usage
    exit 0
fi

AWS_PROFILE=""
TAG="latest"
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --profile|-p)
            AWS_PROFILE="$2"
            shift 2
            ;;
        --tag|-t)
            TAG="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        --)
            shift
            EXTRA_ARGS=("$@")
            break
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ -z "$AWS_PROFILE" ]]; then
    echo "Error: --profile is required"
    echo "Usage: $0 --profile <AWS_PROFILE> [--tag <TAG>] [-- <extra terraform args>]"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! aws sts get-caller-identity --profile "$AWS_PROFILE" &>/dev/null; then
    echo "SSO session expired or missing, logging in for profile: $AWS_PROFILE"
    aws sso login --profile "$AWS_PROFILE"
fi
eval "$(aws configure export-credentials --profile "${AWS_PROFILE}" --format env)"
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text --profile "$AWS_PROFILE")

echo "Running Terraform apply for profile: $AWS_PROFILE (image_tag=${TAG})"
terraform -chdir="$SCRIPT_DIR" init -input=false
terraform -chdir="$SCRIPT_DIR" apply -var-file="./variables.tfvars" -var "account_id=${ACCOUNT_ID}" -var "image_tag=${TAG}" ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}
