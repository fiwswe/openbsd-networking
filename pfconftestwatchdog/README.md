# pf(4) — Safe remote configuration testing

Testing [pf(4)](https://man.openbsd.org/pf) configuration changes on remote servers is potentially dangerous! There is a non-zero chance that the change will prevent admin access to the host. Recovering from such a situation would require console access to the machine.

This mechanism implements a watchdog which allows testing the changes and unless the ok is given by the remote admin will revert to a working configuration.

Note: This is very specific to [OpenBSD](https://openbsd.org). Porting this to another platform should only be attempted if [pf(4)](https://man.openbsd.org/pf) is used on that platform. The basic concepts might work with other local firewalls though. Also remember that the default shell on [OpenBSD](https://openbsd.org) is [ksh(1](https://man.openbsd.org/ksh).

This has been used and tested on [OpenBSD 6.9](https://openbsd.org/69.html) and [OpenBSD 7.0](https://openbsd.org/70.html).


### Files

- `/root/bin/watchdog_pf.sh` is executed every minute using a [cron(8)](https://man.openbsd.org/cron) entry.
- `/root/bin/pf_testconfig.sh` the script used to test configuration changes.
- `/root/bin/watchdog_pf_conf` a library of common shell code included by `watchdog_pf.sh` and `pf_testconfig.sh`.
- `/root/.watchdog-action` a configuration file that defines what the watchdog should do in case of a timeout.
- `/root/.watchdog` a file whose presence arms the watchdog mechanism. Normally this is handled automatically by `pf_testconfig.sh`.


## Implementation

- `watchdog_pf.sh` checks every minute if the watchdog mechanism is armed. If so and if it has been armed long enough (timeout) then the action specified in `.watchdog-action` is executed. This can be a reload of the `/etc/pf.conf` boot configuration or a [reboot(8)](https://man.openbsd.org/reboot) of the machine which will ultimately achieve the same thing.

  - Note: The current timeout is 300 seconds (5 minutes).

- `pf_testconfig.sh` will take the path to the new config file as a parameter. It will first check the syntax and abort if problems are found. If all is well the watchdog is armed and the new config is loaded into [pf(4)](https://man.openbsd.org/pf). The user is then asked to check whether remote access to the machine is still working. If so the user will tell the script which then terminates leaving the new config active.

  - If the user either can't reply to question (because the new config prevents access) or answers that remote access is not possible anymore the watchdog action is triggered, either rebooting the server or reloading the boot configuration for [pf(4)](https://man.openbsd.org/pf).

  - The user can also ask for a time extension.


### Configuration

- ```echo 'reboot' > /root/.watchdog-action``` will cause the triggered watchdog to reboot the machine.
- ```echo 'boot-pf' > /root/.watchdog-action``` will cause the triggered watchdog to reboot the machine. This setting is the safer one because random reboots can't be caused by the accidental presence of the file `.watchdog`.
