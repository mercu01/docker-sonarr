# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.19

# set version label
ARG BUILD_DATE
ARG VERSION
ARG SONARR_VERSION
ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT
ARG BUILDPLATFORM
ARG BUILDOS
ARG BUILDARCH
ARG BUILDVARIANT
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="thespad"

# set environment variables
ENV XDG_CONFIG_HOME="/config/xdg"
ENV SONARR_CHANNEL="v4-stable"
ENV SONARR_BRANCH="main"
RUN echo "I'm building for ${TARGETPLATFORM}"
RUN echo "I'm TARGETOS for ${TARGETOS}"
RUN echo "I'm TARGETARCH for ${TARGETARCH}"
RUN echo "I'm TARGETVARIANT for ${TARGETVARIANT}"
RUN echo "I'm BUILDPLATFORM for ${BUILDPLATFORM}"
RUN echo "I'm BUILDOS for ${BUILDOS}"
RUN echo "I'm BUILDARCH for ${BUILDARCH}"
RUN echo "I'm BUILDVARIANT for ${BUILDVARIANT}"
# environment variables
ENV S6_VERBOSITY=5

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
  echo -e "UpdateMethod=docker\nBranch=${SONARR_BRANCH}\nPackageVersion=${VERSION:-LocalBuild}\nPackageAuthor=[linuxserver.io](https://linuxserver.io)" > /app/sonarr/package_info && \
  echo "**** cleanup ****" && \
  rm -rf \
    /app/sonarr/bin/Sonarr.Update \
    /tmp/*

# add local files
COPY root/ /

# ports and volumes
EXPOSE 8989

VOLUME /config
