#!/bin/bash
set -euo pipefail

AWS_PROFILE=""
BRANCH="main"

while [[ $# -gt 0 ]]; do
    case $1 in
        --profile|-p)
            AWS_PROFILE="$2"
            shift 2
            ;;
        --branch|-b)
            BRANCH="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 --profile <profile> [--branch <branch>]"
            exit 1
            ;;
    esac
done

if [[ -z "$AWS_PROFILE" ]]; then
    echo "Error: --profile is required"
    echo "Usage: $0 --profile <profile> [--branch <branch>]"
    exit 1
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
COMMIT_SHA=$(git rev-parse --short HEAD)
TAG="${CURRENT_BRANCH}.${COMMIT_SHA}"

echo "Profile     : $AWS_PROFILE"
echo "Branch      : $BRANCH"
echo "Tag         : $TAG"
echo "--------------------------------"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "======== Building and Pushing Images ========"
"$SCRIPT_DIR/build_images.sh" --profile "$AWS_PROFILE" --push --no-cache --branch "$BRANCH" --tag "$TAG"

echo "======== Deploying to $AWS_PROFILE ========"
"$REPO_ROOT/terraform/deploy.sh" --profile "$AWS_PROFILE" --tag "$TAG"
