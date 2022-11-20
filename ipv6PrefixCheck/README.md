# Dealing with dynamic IPs in a home/small office setting

## Basic situation
- A VDSL conection provided by [Deutsche Telekom](https://telekom.de) in Germany with dynamic IPv4 and IPv6 addresses
  - Other providers are probably very similar
- An [AVM](https://avm.de) FRITZ!Box as the Router, currently running FRITZ!OS 7.29
- A LAN with multiple devices

The provider advertises 1 public, dynamic IPv4 address to the router using DHCPv4.

The provider advertises 1 public, dynamic IPv6 address (/64) to the router. In combination with the EUI64 interface identifier of the router WAN interface this forms the public, dynamic IP of the router.

The provider additionally advertises 1 public, dynamic IPv6 /56 address prefix to the router. Incoming traffic addressed to IPs from this prefix will be routed to the public, dynamic IP of the router.

The router will advertise a /64 subnet of the public, dynamic IPv6 /56 address prefix to the clients on the LAN. They will typically use SLAAC to configure some of their IPv6 addresses based on this prefix.

The router generally blocks traffic from the Internet from reaching the LAN clients. But port forwarding rules can be configured to allow certain traffic to reach specific LAN clients.
- For IPv4 the combination of the public IPv4 address and a port number and a protocol decide if and where packets are forwarded. (There is also an *exposed host* setting that forwards almost all traffic to the public IPv4 address to one LAN client.)
  - ICMP is a special case.
- For IPv6 the combination of public IPv6 address prefix, subnet specified by FRITZ!OS and the interface identifier forms the public IPv6 address of the LAN client. This in combination with a port number and a protocol decide if and where packets are forwarded.
  - IPv6 forwarding rules hinge on the 64 bit interface identifier of the LAN client. If that IID changes the rule must be adjusted (manually).
  - ICMPv6 is a special case.
  - For the normal LAN the subnet specified by FRITZ!OS is `00`. (For the guest LAN it would be `01`.)

### Example:
- **IPv4**
  - **Public IPv4 address:** `1.2.3.4`

- **IPv6 router**
  - **Public IPv6 router address prefix:** `2001:dead:beaf:42::\64`
  - **Router WAN interface identifier:** `ffff:eeee:dddd:cccc` *EUI64*
  - **Public Router IPv6 address:** `2001:dead:beaf:42:ffff:eeee:dddd:cccc\128`

- **IPv6 LAN clients**
  - **Public IPv6 address prefix:** `2001:dead:cafe::\56`
  - **IPv6 address prefix advertised to LAN clients:** `2001:dead:cafe::\64`

## Issues when trying to have services on LAN clients that are reachable from the Internet
- All the public IPs are dynamic. They *will* change occasionally.
  - Note: At the time of writing Telekom does not force a change very often. Probably every few weeks to months. However there does not seem to be a fixed schedule so preparations need to be made to handle changes at any time.

1. DNS records may need to be updated after a change.
    - For the public IPv4 address and for the public IPv6 address *of the router* the DDNS client in FRITZ!OS can handle this. Note though that the public IPv6 address *of the router* has little practical value unless you want to reach the FRITZ!Box itself.
    - For the public IPv6 addresses of LAN clients the clients will need to handle the updates themselves. It is recommended to use different hostnames than those updated by the DDNS client of FRITZ!OS.
    - Many DDNS services have APIs to allow updates. The details are out of scope for this text.
2. When IPs change, local firewalls and services on the clients may need to have their configuration adjusted.
3. When the public IPv6 prefix changes, LAN clients will generate new addresses. By default they will often use pseudo random interface identiers (*SOII*) which will change when the prefix changes. However the FRITZ!OS port forwarding mechanism hinges on identifying the client based on the interface identifier. If it changes the forwarding rule will no longer work! Manual updates of the configuration become necessary in this case.
    - However using stable EUI64 interface identifiers on the relevant LAN clients can solve this problem.
      - Drawback: EUI64 interface identifiers are based on the interface MAC address in a 1:1 mapping. Thus some information about the vendor of the interface will leak to the outside world. If this is a concern then in some cases a manually generated random MAC address can be configured for the interface. This depends on the OS though. For [OpenBSD](https://obenbsd.org) this is known to be possible.
      - Note: For privacy reasons normal clients used mainly for outgoing traffic (web surfing, etc.) should not use stable interface identifiers. SLAAC and SOII will provide good results for this use case.
4. Detecting changes of the IPv6 prefix can be somewhat challenging.
    - There is no trigger mechanism so polling must be used.
    - Depending on what actions need to be taken when the prefix changes, it may be necessary to know the old and the new prefix, and/or the old and the new IPv6 address.
    - Advertised prefixes and SLAAC take a bit of time to react to changes. E.g. after a reboot it is expected that it will take a few seconds for the IPv6 addresses to become available and stable. An automated solution must take this into account.

## Implementation

Please note again that this is for [OpenBSD 7.0](https://openbsd.org/70.html). And note that [ksh(1)](https://man.openbsd.org/ksh) is used as the default shell in [OpenBSD](https://openbsd.org).

When porting this to a different operating system the [OpenBSD man pages](https://man.openbsd.org/) may be helpful to figure out what this script is supposed to be doing.

### Files
- `/root/bin/ipv6PrefixCheck.sh` the main script run by cron(8).
- `/root/bin/ipv6PrefixChanged.em0` one for each relevant interface, named accordingly, created manually to deal with actions.
- `/root/.lastipv6prefix.em0` one for each relevant interface, named accordingly, created automatically.
- `/var/log/ipv6prefix.log` log file, created automatically.
