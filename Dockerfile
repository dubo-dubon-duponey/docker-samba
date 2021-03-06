ARG           FROM_REGISTRY=ghcr.io/dubo-dubon-duponey

ARG           FROM_IMAGE_RUNTIME=base:runtime-bullseye-2022-05-01@sha256:5e44963d961cf7594cf8a0d1bba98fd5da69d7881cb77c142a43ceab230e87df
ARG           FROM_IMAGE_TOOLS=tools:linux-bullseye-2022-05-01@sha256:6268013e3bd16eaaf7dd15c7689f8740bd00af1149c92795cc42fab4f3c6d07a

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
                samba=2:4.13.13+dfsg-1~deb11u3 \
                samba-vfs-modules=2:4.13.13+dfsg-1~deb11u3 \
                smbclient=2:4.13.13+dfsg-1~deb11u3 \
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

ENV           _SERVICE_NICK="TimeSamba"
ENV           _SERVICE_TYPE="smb"

### mDNS broadcasting
# Whether to enable MDNS broadcasting or not
ENV           MDNS_ENABLED=true
# Type to advertise
ENV           MDNS_TYPE="_$_SERVICE_TYPE._tcp"
# Name is used as a short description for the service
ENV           MDNS_NAME="$_SERVICE_NICK mDNS display name"
# The service will be annonced and reachable at $MDNS_HOST.local (set to empty string to disable mDNS announces entirely)
ENV           MDNS_HOST="$_SERVICE_NICK"
# Also announce the service as a workstation (for example for the benefit of coreDNS mDNS)
ENV           MDNS_STATION=true

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
