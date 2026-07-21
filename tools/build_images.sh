#!/bin/bash
set -e

usage() {
    cat <<EOF
Usage: $0 --profile AWS_PROFILE [OPTIONS]

Build the fornax-cutouts-service Docker image and optionally push to ECR.

Required:
  --profile PROFILE    AWS CLI profile used for ECR login and account lookup

Options:
  --push, -p           Push the image to ECR after building
  --no-cache           Build without using the Docker cache
  --branch BRANCH      fornax-cutouts git branch to build from (default: main)
  --tag, -t TAG        ECR image tag (default: latest)
  --project-name NAME  ECR repository prefix (default: fornax-cutouts; repo is NAME-service)
  --help, -h           Show this help message
EOF
}

# Default values
AWS_PROFILE=""
PUSH=false
NO_CACHE=""
BRANCH="main"
TAG="latest"
PROJECT_NAME="fornax-cutouts"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            usage
            exit 0
            ;;
        --profile)
            AWS_PROFILE="$2"
            shift 2
            ;;
        --push|-p)
            PUSH=true
            shift
            ;;
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        --branch)
            BRANCH="$2"
            shift 2
            ;;
        --tag|-t)
            TAG="$2"
            shift 2
            ;;
        --project-name)
            PROJECT_NAME="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

# Set account ID and profile based on environment
if [ -z "$AWS_PROFILE" ]; then
    echo "Error: AWS_PROFILE is not set"
    exit 1
else
    ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text --profile "$AWS_PROFILE")
fi

ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com"
ECR_REPO="${PROJECT_NAME}-service"

echo "Profile    : $AWS_PROFILE"
echo "Project    : $PROJECT_NAME"
echo "ECR repo   : $ECR_REPO"
echo "Branch     : $BRANCH"
echo "Tag        : $TAG"
echo "No cache   : ${NO_CACHE:-disabled}"
echo "Push       : $PUSH"
echo "Account ID : $ACCOUNT_ID"
echo "--------------------------------"

echo "======== Building Backend ========"
docker build --platform linux/arm64 -f docker/Dockerfile -t fornax-cutouts-service:latest --build-arg FORNAX_CUTOUTS_REPO_BRANCH="$BRANCH" $NO_CACHE .
docker tag fornax-cutouts-service:latest "${ECR_REGISTRY}/${ECR_REPO}:${TAG}"


if [ "$PUSH" == true ]; then
    echo -e "\n"
    echo "======== AWS ECR Push ========"

    echo -e "\n"
    echo "======== Docker Login ========"
    aws ecr get-login-password --region us-east-1 --profile "$AWS_PROFILE" | docker login --username AWS --password-stdin "$ECR_REGISTRY"

    echo -e "\n"
    echo "======== Pushing Backend ========"
    docker push "${ECR_REGISTRY}/${ECR_REPO}:${TAG}"
fi
