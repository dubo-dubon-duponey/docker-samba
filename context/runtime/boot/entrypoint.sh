#!/usr/bin/env bash
set -o errexit -o errtrace -o functrace -o nounset -o pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" 2>/dev/null 1>&2 && pwd)"
readonly root
# shellcheck source=/dev/null
source "$root/helpers.sh"
# shellcheck source=/dev/null
source "$root/mdns.sh"

# Necessary for user accounts creation
helpers::dir::writable /etc

# Data locations
helpers::dir::writable /media/home
helpers::dir::writable /media/share
helpers::dir::writable /media/timemachine

# Typically gets samba logs, lock, pid, etc
helpers::dir::writable /tmp/samba/lock create
helpers::dir::writable /tmp/samba/pid create
helpers::dir::writable /tmp/samba/cache create
helpers::dir::writable /tmp/samba/rpc create
helpers::dir::writable /tmp/samba/logs create
# Normal data location - get samba private and state info
helpers::dir::writable /data/samba/state create
helpers::dir::writable /data/samba/private create

# https://jonathanmumm.com/tech-it/mdns-bonjour-bible-common-service-strings-for-various-vendors/
# https://piware.de/2012/10/running-a-samba-server-as-normal-user-for-testing/
# Model controls the icon in the finder: RackMac - https://simonwheatley.co.uk/2008/04/avahi-finder-icons/

# mDNS
[ "${MOD_MDNS_ENABLED:-}" != true ] || {
  [ "${ADVANCED_MOD_MDNS_STATION:-}" != true ] || mdns::records::add "_workstation._tcp" "${MOD_MDNS_HOST}" "${MOD_MDNS_NAME:-}" 445
  mdns::records::add "${ADVANCED_MOD_MDNS_TYPE:-_smb._tcp}" "${MOD_MDNS_HOST:-}" "${MOD_MDNS_NAME:-}" 445
  mdns::records::add "_device-info._tcp"       "${MOD_MDNS_HOST:-}" "${MOD_MDNS_NAME:-}" 445 '["model='"${MODEL:-RackMac}"'"]'
  mdns::records::add "_adisk._tcp"             "${MOD_MDNS_HOST:-}" "${MOD_MDNS_NAME:-}" 445 '["sys=waMa=0,adVF=0x100", "dk0=adVN=timemachine,adVF=0x82"]'
  mdns::start::broadcaster &
}



# helper to create user accounts
helpers::createUser(){
  local login="$1"
  local password="$2"
  adduser --home "/media/home/$login" --disabled-password --ingroup smb-share --gecos '' "$login" || {
    printf "%s\n" "WARN: failed creating user. Possibly it already exists."
  }

  # Ensure the user timemachine folder is there, owned by them
  helpers::dir::writable "/media/timemachine/$login" create
  chown "$login:smb-share" "/media/timemachine/$login"

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

# Convert log level to samba lingo
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
exec smbd -F --debug-stdout -d="$ll" --no-process-group --configfile=/config/samba/main.conf "$@"
