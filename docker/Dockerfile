####
FROM ghcr.io/astral-sh/uv:python3.13-trixie AS builder

# Fornax Cutouts repository organization and branch to clone, currently needed until the Fornax Cutouts package is published to PyPI
ARG FORNAX_CUTOUTS_REPO_ORG=dsarmiento
ARG FORNAX_CUTOUTS_REPO_BRANCH=main

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=0

WORKDIR /opt/fornax-cutouts
RUN git clone \
    --branch="${FORNAX_CUTOUTS_REPO_BRANCH}" \
    --depth=1 \
    "https://github.com/${FORNAX_CUTOUTS_REPO_ORG}/fornax-cutouts.git" "/opt/fornax-cutouts"

# Create a virtual environment for the project, install dependencies, and copy the project code
WORKDIR /opt/cutouts
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-install-project --no-dev
COPY cutouts ./cutouts/
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev

####
FROM python:3.13-trixie

# Update the base image and clean up
RUN apt-get update \
 && apt-get upgrade -y \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists

# Create a user and group for the project
RUN groupadd --system --gid 999 cutouts \
 && useradd --system --gid 999 --uid 999 --create-home --home-dir /home/cutouts cutouts

# Copy the virtual environment and entrypoint script from the builder image
COPY --chown=cutouts:cutouts --from=builder /opt /opt
COPY --chown=cutouts:cutouts docker/entrypoint.sh /opt/cutouts

# Set environment variables for the project
ENV PATH="/opt/cutouts/.venv/bin:$PATH" \
    PYTHONPATH=/opt/cutouts \
    CUTOUTS__SOURCE_PATH=/opt/cutouts/cutouts/sources

# Set the user and working directory for the project
USER cutouts
WORKDIR /opt/cutouts

# Set the entrypoint and command for the container
ENTRYPOINT [ "./entrypoint.sh" ]
CMD [ "help" ]
