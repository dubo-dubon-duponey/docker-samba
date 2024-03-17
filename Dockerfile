ARG           FROM_REGISTRY=docker.io/dubodubonduponey

ARG           FROM_IMAGE_RUNTIME=base:runtime-bookworm-2024-03-01
ARG           FROM_IMAGE_TOOLS=tools:linux-bookworm-2024-03-01

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
                samba=2:4.17.12+dfsg-0+deb12u1 \
                samba-vfs-modules=2:4.17.12+dfsg-0+deb12u1 \
                smbclient=2:4.17.12+dfsg-0+deb12u1 && \
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
ENV           MOD_MDNS_ENABLED=true
# Type to advertise
ENV           MOD_MDNS_TYPE="_$_SERVICE_TYPE._tcp"
# Name is used as a short description for the service
ENV           MOD_MDNS_NAME="$_SERVICE_NICK mDNS display name"
# The service will be annonced and reachable at $MOD_MDNS_HOST.local (set to empty string to disable mDNS announces entirely)
ENV           MOD_MDNS_HOST="$_SERVICE_NICK"
# Also announce the service as a workstation (for example for the benefit of coreDNS mDNS)
ENV           ADVANCED_MOD_MDNS_STATION=true

ENV           MODEL="RackMac"
ENV           USERS=""
ENV           PASSWORDS=""

EXPOSE        445

# Necessary for users creation - XXX this is problematic as it will keep back /etc/apt for eg
VOLUME        /etc

# Data location
VOLUME        /media/home
VOLUME        /media/timemachine
VOLUME        /media/share

VOLUME        /data
VOLUME        /tmp

HEALTHCHECK   --interval=120s --timeout=30s --start-period=10s --retries=1 CMD smbclient -L \\localhost -U % -m SMB3 || exit 1
