# What

A docker image for [Samba](https://www.samba.org/) geared towards TimeMachine backups.

## Image features

 * multi-architecture:
   * [x] linux/amd64
   * [x] linux/arm64
 * hardened:
    * [x] image runs read-only
    * [ ] image runs with ~~no capabilities~~ the following capabilities:
        * NET_BIND_SERVICE
        * CHOWN
        * FOWNER
        * SETUID
        * SETGID
        * DAC_OVERRIDE
    * [ ] process runs as a non-root user, disabled login, no shell
        * the entrypoint script runs as root
 * lightweight
    * [x] based on our slim [Debian Bookworm](https://github.com/dubo-dubon-duponey/docker-debian)
    * [x] simple entrypoint script
    * [ ] multi-stage build with ~~zero packages~~ `samba`, `samba-vfs-modules`, `smbclient` installed in the runtime image
 * observable
    * [x] healthcheck
    * [x] log to stdout
    * [ ] ~~prometheus endpoint~~ not applicable

## Run


```bash
docker run -d --rm \
        --name samba \
        --env MOD_MDNS_NAME=samba \
        --env MOD_MDNS_HOST=TimeSamba \
        --env USERS=dubo-dubon-duponey \
        --env PASSWORDS=replace_me \
        --read-only \
        --net host \
        --user root \
        --cap-drop ALL \
        --cap-add DAC_OVERRIDE \
        --cap-add FOWNER \
        --cap-add NET_BIND_SERVICE \
        --cap-add CHOWN \
        --cap-add SETUID \
        --cap-add SETGID \
        --volume [host_path]:/media/home \
        --volume [host_path]:/media/share \
        --volume [host_path]:/media/timemachine \
        docker.io/dubodubonduponey/samba
```

## Notes

### Networking

You need to run this in `host` or `mac(or ip)vlan` networking (because of mDNS).

### Configuration

The following extra environment variables lets you further configure the image behavior:

* MOD_MDNS_HOST controls the host part under which the service is being announced (eg: $MOD_MDNS_HOST.local)
  * If set empty, will disable mDNS announcements altogether
* MOD_MDNS_NAME controls the fancy name
* USERS is a space separated list of users
* PASSWORDS is a space separated list of passwords

The image runs read-only, but the following volumes are mounted rw:
* /etc this is necessary to allow for on-the-fly user creation
* /media/home where users homes are located
* /media/share where the common share is located
* /media/timemachine where the timemachine backups are located
* /data where Samba will keep its system data
* /tmp where Samba will keep its transient data

Samba is started with -c /config/samba/main.conf

You may evidently mount this file to further control samba configuration and behavior.

### Advanced configuration

Any additional arguments when running the image will get fed to the `samba` binary.

## Debugging TimeMachine

From a mac:

```
log show --predicate 'subsystem == "com.apple.TimeMachine"' --info | grep 'upd: (' | cut -c 1-19,140-999
```

## Moar?

See [DEVELOP.md](DEVELOP.md)
