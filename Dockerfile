ARG           FROM_REGISTRY=ghcr.io/dubo-dubon-duponey

ARG           FROM_IMAGE_RUNTIME=base:runtime-bullseye-2021-10-01@sha256:5c76496f4dc901e9a59370babd9fa3c59427064971058b373121140a29fb153f
ARG           FROM_IMAGE_TOOLS=tools:linux-bullseye-2021-10-01@sha256:b08c3c560b8c05fc9305b781529805c5fd2490db953497a2236063069435672f

FROM          $FROM_REGISTRY/$FROM_IMAGE_TOOLS                                                                          AS builder-tools

#######################
# Running image
#######################
FROM          $FROM_REGISTRY/$FROM_IMAGE_RUNTIME

# hadolint ignore=DL3002
USER          root

# Install dependencies and tools
RUN           --mount=type=secret,uid=100,id=CA \
              --mount=type=secret,uid=100,id=CERTIFICATE \
              --mount=type=secret,uid=100,id=KEY \
              --mount=type=secret,uid=100,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_CONFIG \
              apt-get update -qq && \
              apt-get install -qq --no-install-recommends \
                samba=2:4.13.5+dfsg-2 \
                samba-vfs-modules=2:4.13.5+dfsg-2 \
                smbclient=2:4.13.5+dfsg-2 \
                && \
              apt-get -qq autoremove      && \
              apt-get -qq clean           && \
              rm -rf /var/lib/apt/lists/* && \
              rm -rf /tmp/*               && \
              rm -rf /var/tmp/*

RUN           groupadd smb-share \
              && mkdir -p /media/home \
              && mkdir -p /media/share \
              && mkdir -p /media/timemachine \
              && chown "$BUILD_UID":smb-share /media/home \
              && chown "$BUILD_UID":smb-share /media/share \
              && chown "$BUILD_UID":smb-share /media/timemachine \
              && chmod g+srwx /media/home \
              && chmod g+srwx /media/share \
              && chmod g+srwx /media/timemachine

# Unclear if we need: tracker libtracker-sparql-1.0-dev (<- provides spotlight search thing)

# Samba core dumps location, not configurable and cannot be disabled
RUN           rm -Rf /var/log/samba; ln -s /tmp/samba/logs /var/log/samba

USER          dubo-dubon-duponey

COPY          --from=builder-tools --chown=$BUILD_UID:root /boot/bin/goello-server-ng /boot/bin/goello-server-ng

# Name is used as a short description for the service
ENV           MDNS_NAME="TimeSamba"
# The service will be annonced and reachable at $MDNS_HOST.local
ENV           MDNS_HOST="TimeSamba"

ENV           MDNS_MODEL="RackMac"

ENV           USERS=""
ENV           PASSWORDS=""

EXPOSE        445

# Necessary for users creation
VOLUME        /etc

# Data location
VOLUME        /media/home
VOLUME        /media/timemachine
VOLUME        /media/share

VOLUME        /data
VOLUME        /tmp

HEALTHCHECK   --interval=120s --timeout=30s --start-period=10s --retries=1 CMD smbclient -L \\localhost -U % -m SMB3 || exit 1
