ARG BASE_IMAGE=ghcr.io/ublue-os/base-main:45

# Build context: scripts and files used during the build, not copied into the image
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files
COPY cosign.pub /cosign.pub

FROM ${BASE_IMAGE}

ARG BASE_IMAGE
ARG BASE_IMAGE_DIGEST=unknown
ARG AERINITE_VERSION=local

LABEL org.opencontainers.image.base.name="$BASE_IMAGE"
LABEL org.opencontainers.image.base.digest="$BASE_IMAGE_DIGEST"

# Packages, branding, config and services: see build_files/build.sh
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

RUN bootc container lint
