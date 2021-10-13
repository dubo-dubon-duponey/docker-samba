#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

# https://piware.de/2012/10/running-a-samba-server-as-normal-user-for-testing/

# XXX temporary, as this should be ported into our base debian image
export GNUTLS_FORCE_FIPS_MODE=1

[ -w /tmp ] || {
  printf >&2 "/tmp is not writable. Check your mount permissions.\n"
  exit 1
}

[ -w /data ] || {
  printf >&2 "/data is not writable. Check your mount permissions.\n"
  exit 1
}

mkdir -p /tmp/samba/lock
mkdir -p /tmp/samba/pid
mkdir -p /tmp/samba/cache
mkdir -p /tmp/samba/rpc
mkdir -p /tmp/samba/logs
mkdir -p /data/samba/state
mkdir -p /data/samba/private

# Test if this gets into the config
# Purely tentative
# Does not seem to work
# SMB_WORKGROUP=loliworkgroup

# enable core files = no
# /var/log/samba/cores

# mDNS announce for both Time Machine and SMB shares
if [ "${MDNS_ENABLED:-}" == true ]; then
  smbrecord="$(printf '{"Type": "%s", "Name": "%s", "Host": "%s", "Port": %s, "Text": {}}' \
    "$MDNS_TYPE" \
    "$MDNS_NAME" \
    "$MDNS_HOST" \
    445)"
  device_info="$(printf '{"Type": "%s", "Name": "%s", "Host": "%s", "Port": %s, "Text": %s}' \
    "_device-info._tcp" \
    "$MDNS_NAME" \
    "$MDNS_HOST" \
    9 \
    '{"model": "Dubo"}')"
  diskrecord="$(printf '{"Type": "%s", "Name": "%s", "Host": "%s", "Port": %s, "Text": %s}' \
    "_adisk._tcp" \
    "$MDNS_NAME" \
    "$MDNS_HOST" \
    9 \
    '{"sys": "waMa=0,adVF=0x100", "dk0": "adVN=timemachine,adVF=0x82"}')"

  goello-server -json "$(printf '[%s, %s, %s]'  "$smbrecord" "$diskrecord" "$device_info")" &

  #goello-server -name "$MDNS_NAME" -host "$MDNS_HOST" -type "$MDNS_TYPE" -port 445 &
  # XXX not completely sure what to do as port 0 is invalid
  # goello-server -name "$MDNS_NAME" -host "$MDNS_HOST" -type "_device-info._tcp" -port 0 -txt '{"model": "Dancing Samba"}' &
  # Port 9 is unconfirmed, and stolen from what netatalk is doing
  # Also netatalk is doing adVF=0xa1,adVU=BC7C370A-A832-BD45-1208-A8E6606A156A <- instead of adVF=0x82
  #goello-server -name "$MDNS_NAME" -host "$MDNS_HOST" -type "_adisk._tcp" -port 9 \
  #  -txt '{"sys": "waMa=0,adVF=0x100", "dk0": "adVN=Time Machine,adVF=0x82"}'  &
fi

# helper to create user accounts
helpers::createUser(){
  local login="$1"
  local password="$2"
  adduser --home "/media/home/$login" --disabled-password --ingroup smb-share --gecos '' "$login" || {
    printf "%s\n" "WARN: failed creating user. Possibly it already exists."
  }

  printf "%s:%s" "$login" "$password" | chpasswd
  printf "%s\n%s\n" "$password" "$password" | smbpasswd -c /config/samba/main.conf -a "$login"
}

# shellcheck disable=SC2206
USERS=($USERS)
# shellcheck disable=SC2206
PASSWORDS=($PASSWORDS)

printf "Creating users\n"
for ((index=0; index<${#USERS[@]}; index++)); do
  helpers::createUser "${USERS[$index]}" "${PASSWORDS[$index]}"
done

ll=0
case "${LOG_LEVEL:-warn}" in
  "debug")
    ll=3
  ;;
  "info")
    ll=2
  ;;
  "warn")
    ll=1
  ;;
  "error")
    ll=0
  ;;
esac

# Foreground -F, log to stdout -S, debug level -d, unclear "no process group"
exec smbd -FS -d="$ll" --no-process-group --configfile=/config/samba/main.conf "$@"
