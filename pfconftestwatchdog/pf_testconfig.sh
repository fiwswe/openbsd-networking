#!/bin/sh
# Copyright (c)2021-2022 by fiwswe

PROGRAM="${0##*/}"
RCCTL_CMD='/usr/sbin/rcctl'
DIRNAME_CMD='/usr/bin/dirname'


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


function do_usage
{
	echo "Usage: ${PROGRAM} <path-to-pf.conf>"
	echo "  Note that the tested config must be different from ${BOOT_PF_CONFIG}."
}

function do_error
{
	echo "# ERROR: $1"
	do_usage
	exit 1
}

function do_abort
{
	disarm_watchdog
	if [ $DRY_RUN -eq 0 ];then
		echo "DRY RUN: User canceled. Would have loaded ${BOOT_PF_CONFIG} to abort the test."
		exit 1
	else
		load_pf_boot_config
		do_error "User canceled. Loaded ${BOOT_PF_CONFIG} to abort the test."
	fi
}

#	Make sure that we are running as root:
[[ $($ID_CMD -ru) -eq 0 ]]||do_fatal "${PROGRAM} must be run as 'root'! (Current user is '${USER}'.)"

#	Is pf(4) running?
$RCCTL_CMD ls on|grep -qE 'pf$'
if [ $? -ne 0 ];then
	do_fatal "pf(4) is not running!"
fi

#	Do we have a valid parameter (a pf.conf file)?
if [ $# -ne 1 ];then
	do_error 'Please specify a pf(4) config file to test.'
fi
if [ "$1" = "$BOOT_PF_CONFIG" ];then
	do_error "Can not test ${BOOT_PF_CONFIG} as that is the fallback."
fi
if [ ! -f "$1" ];then
	do_error "$1 does not seem to be a pf(4) config file."
fi
#	Is our fallback config valid?
$PFCTL_CMD -nf "$BOOT_PF_CONFIG"||do_error "Syntax error in ${BOOT_PF_CONFIG}!!! DANGER: Fix this immediately please as this is the boot and fallback config for pf(4)."

#	Is this a dry-run?
DRY_RUN=0
if [ -f "$WATCHDOG_ACTION" ];then
	$GREP_CMD -q "$WATCHDOG_ACTION_BOOTPF" "$WATCHDOG_ACTION"&&DRY_RUN=1
	$GREP_CMD -q "$WATCHDOG_ACTION_REBOOT" "$WATCHDOG_ACTION"&&DRY_RUN=1
	if [ $DRY_RUN -eq 0 ];then
		echo "DRY RUN: Because ${WATCHDOG_ACTION} does not contain '${WATCHDOG_ACTION_BOOTPF}' or '${WATCHDOG_ACTION_REBOOT}'."
	fi
else
	echo "DRY RUN: Because ${WATCHDOG_ACTION} does not exist."
fi


#	Step 1: Test the syntax of the new pf(4) configuration file:
$PFCTL_CMD -nf "$1"||do_error "Syntax error in $1! Fix and try again."

#	Step 2: Arm the watchdog mechanism:
arm_watchdog

#	Step 3: Load the new pf(4) configuration:
if [ $DRY_RUN -eq 0 ];then
	echo "DRY RUN: Would now load $1 into pf(4). Skipping in a dry-run."
else
	$PFCTL_CMD -f "$1"
fi

#	Step 4: Inform the user and ask for admin access test result:
echo "$(date +'%F %T'): Loaded $1 into pf(4). Please test admin access to the machine within the next ${TRIGGER_SECS} seconds."
echo "You may reset this timeout to another ${TRIGGER_SECS} seconds by answering with anything but 'y[es]', 'n[o]' or 'c[ancel]'."
trap do_abort SIGHUP SIGINT SIGTERM
while true;do
	read ANSWER?'Is admin access to this machine still working? (y[es]/n[o]/c[ancel]/extend) '
	case $ANSWER in
		[Yy]*)
			disarm_watchdog
			if [ $DRY_RUN -eq 0 ];then
				echo "DRY RUN: Would keep $1 active."
			else
				echo "Keeping $1 active."
			fi
			exit 0
			;;
		[Nn]*)
			disarm_watchdog
			if [ $DRY_RUN -eq 0 ];then
				echo "DRY RUN: Would have loaded ${BOOT_PF_CONFIG}. Fix the problem in $1 and try again."
			else
				load_pf_boot_config
				echo "Loaded ${BOOT_PF_CONFIG}. Fix the problem in $1 and try again."
			fi
			exit 0
			;;
		[Cc]*)
			disarm_watchdog
			if [ $DRY_RUN -eq 0 ];then
				echo "DRY RUN: Would have canceled test and loaded ${BOOT_PF_CONFIG}."
			else
				load_pf_boot_config
				echo "Canceled test and loaded ${BOOT_PF_CONFIG}."
			fi
			exit 0
			;;
		*)
			reset_watchdog
			echo "$(date +'%F %T'): reset timeout to ${TRIGGER_SECS} seconds from now."
			;;
	esac
done


#	Local Variables:
#	tab-width: 4
#	End:

#
# EOF.
#
