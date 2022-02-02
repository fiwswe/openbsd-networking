#!/bin/sh
# Copyright (c)2021-2022 by fiwswe
# Watchdog mechanism for testing dangerous pf.conf(5) configurations.
# This script should be run in regular intervals using cron(1) as root, e.g.:
# *	*	*	*	*	/root/bin/watchdog_pf.sh
#
# Usage:
# - Arm the mechanism by creating the watchdog file.
#   Example: touch /root/.watchdog
# - Once created modify the file manually within the trigger period to prevent triggering the watchdog action.
#   Failing to do so will trigger the watchdog action.
#   Example: touch /root/.watchdog
# - Disarm the mechanism by deleting the watchdog file.
#   Example: rm /root/.watchdog

PROGRAM="${0##*/}"
DIRNAME_CMD='/usr/bin/dirname'
REBOOT_CMD='/sbin/reboot'

function do_fatal
{
	echo "### ERROR: $1" >&2
	exit 1
}


#LIB='/root/bin/watchdog_pf_conf'
LIB="$($DIRNAME_CMD $0)/watchdog_pf_conf"
if [ -f "$LIB" ];then
	. "$LIB"
else
	do_fatal "${LIB} missing!"
fi


function action_load_boot_pf
{
	do_log "Action: load ${BOOT_PF_CONFIG}"
	load_pf_boot_config
	exit 0
}

function action_reboot
{
	do_log 'Action: reboot'
	$REBOOT_CMD
	exit 0
}


#	Make sure that we are running as root:
#if [ "$USER" != 'root' ];then
#	echo "### ERROR: $0 must be run as 'root'! (Current user is '${USER}'.)" >&2
#	exit 1
#fi
[[ $($ID_CMD -ru) -eq 0 ]]||do_fatal "${PROGRAM} must be run as 'root'! (Current user is '${USER}'.)"


# If the watchdog file is missing, do nothing:
if [ ! -f "$WATCHDOG_FILE" ];then
	do_debug 'not armed'
	exit 0
fi
 
# If the watchdog file was modified recently enough, do nothing:
NOW=$(date '+%s')
TRIGGER=$(stat -f '%m' "$WATCHDOG_FILE")
REF=$(($TRIGGER+$TRIGGER_SECS))
do_debug "NOW: $NOW"
do_debug "TRIGGER file: $TRIGGER"
do_debug "TRIGGER time: $REF"
if [ $REF -gt $NOW ];then
	do_debug 'not triggered'
	exit 0
fi
 
# Watchdog action:
# Step 1: Log that the action was triggered:
do_log "### Watchdog triggered in $0"
# Step 2: Disarm the watchdog mechanism to prevent later retriggering to avoid loops where the server is rebooted endlessly:
disarm_watchdog
# Step 3: The actual action:
if [ -f "$WATCHDOG_ACTION" ];then
	# 3a: Option 1: Or just reload pf(4) with a known good config:
	$GREP_CMD -q "$WATCHDOG_ACTION_BOOTPF" "$WATCHDOG_ACTION"&&action_load_boot_pf
	# 3b: Option 2: Drastic action:
	$GREP_CMD -q "$WATCHDOG_ACTION_REBOOT" "$WATCHDOG_ACTION"&&action_reboot
fi
# 3c: Option 3: Do nothing
do_log 'Action: none'


#	Local Variables:
#	tab-width: 4
#	End:
 
#
# EOF.
#
