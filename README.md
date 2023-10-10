# OCSERV
OpenConnect Server (ocserv) one-click installation script forked from doub.io backup.

### Get Started
Executive this:
```shell
sudo wget -N --no-check-certificate https://github.com/spectatorzhang/ocserv/raw/master/ocserv.sh && chmod +x ocserv.sh && bash ocserv.sh
```

### What's changed?
- Update OCSERV version to the latest one
- Disable banner display for more convenient connection experience
- Enable compression for faster transfer speed, while allow low-latency-demand applications like VOIP to bypass it
- Enable MTU autodiscovery
