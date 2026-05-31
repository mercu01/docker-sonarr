# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.23

# set version label
ARG BUILD_DATE
ARG VERSION
ARG SONARR_VERSION
ARG TARGETARCH
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="thespad"

# set environment variables
ENV XDG_CONFIG_HOME="/config/xdg" \
  SONARR_CHANNEL="v4-stable" \
  SONARR_BRANCH="main" \
  COMPlus_EnableDiagnostics=0 \
  TMPDIR=/run/sonarr-temp

COPY \
  linux-musl-x64.tar.gz \
  /tmp/linux-musl-x64.tar.gz
COPY \
  linux-musl-arm64.tar.gz \
  /tmp/linux-musl-arm64.tar.gz
RUN if [ "$TARGETARCH" = "amd64" ]; then \
  cp /tmp/linux-musl-x64.tar.gz /tmp/sonarr.tar.gz; \
  elif [ "$TARGETARCH" = "arm64" ]; then \
  cp /tmp/linux-musl-arm64.tar.gz /tmp/sonarr.tar.gz; \
  fi

RUN \
  echo "**** install packages ****" && \
  apk add --no-cache \
  icu-libs \
  sqlite-libs \
  xmlstarlet && \
  echo "**** install sonarr ****" && \
  mkdir -p /app/sonarr/bin && \
  tar xzf \
  /tmp/sonarr.tar.gz -C \
  /app/sonarr/bin --strip-components=1 && \
  chmod +x /app/sonarr/bin/Sonarr && \
  echo -e "UpdateMethod=docker\nBranch=${SONARR_BRANCH}\nPackageVersion=${VERSION:-LocalBuild}\nPackageAuthor=[linuxserver.io](https://linuxserver.io)" > /app/sonarr/package_info && \
  printf "Linuxserver.io version: ${VERSION}\nBuild-date: ${BUILD_DATE}" > /build_version && \
  echo "**** cleanup ****" && \
  rm -rf \
  /app/sonarr/bin/Sonarr.Update \
  /tmp/*

# add local files
COPY root/ /

# ports and volumes
EXPOSE 8989

VOLUME /config
