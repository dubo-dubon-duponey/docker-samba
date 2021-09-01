ARG           FROM_REGISTRY=ghcr.io/dubo-dubon-duponey

ARG           FROM_IMAGE_RUNTIME=base:runtime-bullseye-2021-09-01@sha256:bbd3439247ea1aa91b048e77c8b546369138f910b5083de697f0d36ac21c1a8c
ARG           FROM_IMAGE_TOOLS=tools:linux-bullseye-2021-09-01@sha256:e5535efb771ca60d2a371cd2ca2eb1a7d6b7b13cc5c4d27d48613df1a041431d

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

RUN           mkdir -p /boot/bin; chown "$BUILD_UID":root /boot/bin
# Samba core dumps location, not configurable and cannot be disabled
RUN           rm -Rf /var/log/samba; ln -s /tmp/samba/logs /var/log/samba

USER          dubo-dubon-duponey

COPY          --from=builder-tools --chown=$BUILD_UID:root /boot/bin/goello-server /boot/bin

ENV           NICK=TimeMassine

### mDNS broadcasting
# Enable/disable mDNS support
ENV           MDNS_ENABLED=false
# Name is used as a short description for the service
ENV           MDNS_NAME="$NICK mDNS display name"
# The service will be annonced and reachable at $MDNS_HOST.local
ENV           MDNS_HOST="$NICK"
# Type to advertise
ENV           MDNS_TYPE="_smb._tcp"

# XXX disable healthchecker for now
# COPY          --from=builder-healthcheck /dist/boot           /dist/boot
# RUN           chmod 555 /dist/boot/bin/*

#VOLUME        /var/log
#VOLUME        /data
#VOLUME        /run
#EXPOSE        548
#EXPOSE 137/udp 138/udp 139 445
#VOLUME ["/etc", "/var/cache/samba", "/var/lib/samba", "/var/log/samba",            "/run/samba"]

EXPOSE        445
EXPOSE        9

ENV           USERS=""
ENV           PASSWORDS=""

# Necessary for users creation
VOLUME        /etc
# Data location
VOLUME        /media/home
VOLUME        /media/timemachine
VOLUME        /media/share
# Samba permanent stuff
VOLUME        /data
# Samba transient stuff
VOLUME        /tmp

HEALTHCHECK   --interval=120s --timeout=30s --start-period=10s --retries=1 CMD smbclient -L \\localhost -U % -m SMB3 || exit 1
