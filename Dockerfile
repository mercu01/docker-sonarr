# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.19

# set version label
ARG BUILD_DATE
ARG VERSION
ARG ARCH

LABEL build_version="Modified version of sonarr for wolfmax4k, atomoHD, atomixHQ, sinsitio, eldesvandelverdugo, etc. https://github.com/mercu01/Sonarr"
LABEL maintainer="mercu"

# set environment variables
ENV XDG_CONFIG_HOME="/config/xdg"
ENV SONARR_CHANNEL="v4-stable"
ENV SONARR_BRANCH="main"
RUN \
    echo "${ARCH}"
COPY \
    linux-x64.tar.gz \
    /tmp/linux-x64.tar.gz
COPY \
    linux-musl-arm64.tar.gz \
    /tmp/linux-musl-arm64.tar.gz
RUN if [ "$ARCH" = "x64" ]; then \
        cp /tmp/linux-x64.tar.gz /tmp/sonarr.tar.gz; \
    elif [ "$ARCH" = "arm64" ]; then \
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
  echo -e "UpdateMethod=docker\nBranch=${SONARR_BRANCH}\nPackageVersion=${VERSION:-LocalBuild}\nPackageAuthor=[mercu](https://github.com/mercu01/docker-sonarr)" > /app/sonarr/package_info && \
  echo "**** cleanup ****" && \
  rm -rf \
    /app/sonarr/bin/Sonarr.Update \
    /tmp/*

# add local files
COPY root/ /

# ports and volumes
EXPOSE 8989

VOLUME /config
