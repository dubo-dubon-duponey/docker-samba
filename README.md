# What

A docker image for [Samba](https://www.samba.org/) geared towards TimeMachine backups.

## Image features

 * multi-architecture:
   * [x] linux/amd64
   * [x] linux/arm64
   * [x] linux/arm/v7
   * [x] linux/arm/v6
   * [x] linux/ppc64le
   * [x] linux/386
   * [ ] linux/s39àx
 * hardened:
    * [x] image runs read-only
    * [ ] image runs with the following capabilities:
        * NET_BIND_SERVICE
        * CHOWN
        * FOWNER
        * SETUID
        * SETGID
        * DAC_OVERRIDE
    * [ ] process runs as a non-root user, disabled login, no shell
        * the entrypoint script runs as root
 * lightweight
    * [x] based on our slim [Debian bullseye version (2021-08-01)](https://github.com/dubo-dubon-duponey/docker-debian)
    * [x] simple entrypoint script
    * [ ] multi-stage build with ~~no installed~~ dependencies for the runtime image:
        * samba
        * samba-vfs-modules
        * smblcient
 * observable
    * [ ] ~~healthcheck~~
    * [x] log to stdout
    * [ ] ~~prometheus endpoint~~ not applicable

## Run


```bash
docker run -d --rm \
        --name samba \
        --network host_or_vlan \
        --env MDNS_ENABLED=true \
        --env USERS=dubo-dubon-duponey \
        --env PASSWORDS=replace_me \
        --read-only \
        --user root \
        --cap-drop ALL \
        --cap-add DAC_OVERRIDE \
        --cap-add FOWNER \
        --cap-add NET_BIND_SERVICE \
        --cap-add CHOWN \
        --cap-add SETUID \
        --cap-add SETGID \
        ghcr.io/dubo-dubon-duponey/samba
```

## Notes

### Networking

You need to run this in `host` or `mac(or ip)vlan` networking (because of mDNS).

### Configuration

The following extra environment variables lets you further configure the image behavior:

* MDNS_ENABLED lets you control whether Samba will announce itself over mDNS
* MDNS_HOST controls the host part under which the service is being announced (eg: $MDNS_HOST.local)
* MDNS_NAME controls the fancy name
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

## Moar?

See [DEVELOP.md](DEVELOP.md)
