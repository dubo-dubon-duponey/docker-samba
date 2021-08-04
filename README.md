# What

A docker image for [Samba](https://www.samba.org/) geared towards TimeMachine.

Missing:
* review https://gist.github.com/ChloeTigre/4c2022c0d1a281deedba6f7539a2e3ae
* https://wiki.samba.org/index.php/Configure_Samba_to_Work_Better_with_Mac_OS_X
* https://developer.apple.com/forums/thread/666293
* https://github.com/dperson/samba/blob/master/_etc_avahi_services_samba.service

## Image features

 * multi-architecture:
    * [x] linux/amd64
    * [x] linux/arm64
    * [x] linux/arm/v7
    * [ ] linux/arm/v6 (should build, disabled by default)
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
        * the entrypoint script still runs as root before dropping privileges (due to avahi-daemon)
 * lightweight
    * [x] based on our slim [Debian bullseye version (2021-08-01)](https://github.com/dubo-dubon-duponey/docker-debian)
    * [x] simple entrypoint script
    * [ ] multi-stage build with ~~no installed~~ dependencies for the runtime image:
        * dbus
        * avahi-daemon
        * netatalk
 * observable
    * [ ] ~~healthcheck~~
    * [x] log to stdout
    * [ ] ~~prometheus endpoint~~ not applicable

## Run

```bash
docker run -d --rm \
```

## Notes

### Networking

You need to run this in `host` or `mac(or ip)vlan` networking (because of mDNS).

### Configuration

An extra environment variable (`AVAHI_NAME`) allows you to specify a different
name for the avahi workstation. If left unspecified, it will fallback to the value of `NAME`.

You may specify as many users/passwords as you want (space separated).

Home directories are accessible only by the corresponding user.

`share` is accessible by all users.

`timemachine` is accessible by all users as well (hint: backups SHOULD then be encrypted by their respective owners).

Guest access does not work currently, and is disabled.

### Advanced configuration

Would you need to, you may optionally pass along:
 
 * `--volume [host_path]/afp.conf:/etc/afp.conf`
 * `--volume [host_path]/avahi-daemon.conf:/etc/avahi/avahi-daemon.conf`

Also, any additional arguments when running the image will get fed to the `netatalk` binary.

## Moar?

See [DEVELOP.md](DEVELOP.md)
