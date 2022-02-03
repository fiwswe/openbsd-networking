#!/bin/sh
#	Copyright (c)2021-2022 by fiwswe
#	Based on the script IPv6Aliasses-en.sh by Thomas Bohl
#	See: https://aloof.de/f/IPv6Aliases-en.sh
#
#	This script will determine the public IPv6 address prefix, compare it to the most
#	recent one and if different trigger a number of actions to be performed.
#
#	For each interface a separate script file is included (executed) when a change is
#	detected. This file will have access to the old and new IPv6 address prefix and the
#	interface name.
#
#	The last known IPv6 prefix is cached in a file.
#
#	Logs of all relevant events are written to a log file.
#
#	The script is meant to run as often as possible (each minute) from a root crontab:
#	* * * * * /root/bin/ipv6PrefixCheck.sh
#

#	Set this variable to 1 to enable debug outout:
DEBUG=0

LOGFILE='/var/log/ipv6prefix.log'
CACHEFILE='/root/.lastipv6prefix.'
CHANGEACTIONPATH='/root/bin/ipv6PrefixChanged.'


#	Print and log a message.
#	Parameters:
#		message		The string to print.
function printMessage
{
	echo "$(date '+%Y%m%d-%H%M%S'): $1" >> "$LOGFILE"
	echo "$1"
}

#	Print and log a debug message.
#	Parameters:
#		message		The string to print if debugging is on.
function printDebug
{
	[ $DEBUG -eq 1 ] && printMessage "DEBUG: $1"
}

#	Print/log a message if in debug mode, then exit normally.
#	Parameters:
#		message		The string to print if debugging is on.
function exitWithMessage
{
	printDebug "$1"
	exit
}

#	Wait until the system has at least two minutes of uptime.
#	slaacd(8) may need this time to configure all IPv6 addresses.
function delayAfterBoot
{
	local myUptime=$(( $(date +%s) - $(sysctl -n kern.boottime) ))

	printDebug "Uptime: ${myUptime} s"
	[ $myUptime -lt 120 ] && exitWithMessage "Still waiting for SLAAC after a reboot ${myUptime} seconds ago."
}

#	Utility function to build a valid IPv6 address given an address prefix and an IID.
#	Parameters:
#		prefix	The IPv6 address prefix (without trailing '::/n')
#				May not contain any '::'!
#		iid		The interface identifier.
#				May not contain any '::'!
function buildIPv6Addr
{
	local prefix="$1"
	local iid="$2"

	#	Note: Due to the way the prefix was extracted from the route(8) command it can
	#	not contain any '::'.
	#	As the iid is defined manually we can make sure that it does not contain any
	#	'::' either.
	#	Thus using '::'' as a separator between the prefix and the iid is fine if both of
	#	them together contain less than 6 ':'.
	#	The logic is not perfect here but it seems to work for now.

	#	Extract the ':' characters in the prefix and iid:
	local sp=$(echo "${prefix}${iid}"|tr -dc ':')

	#	If either the prefix or the IID has less than 3 ':' then use separator '::'.
	#	Otherwise use separator ':'.
	local s=':'
	if [ "$sp" != '::::::' ]; then
		s='::'
	fi

	echo "${prefix}${s}${iid}"
}

#	Utility function to get the public IPv4 address (of the router) for a given interface.
#	Parameters:
#		interface	The interface for which to get the public IPv4 address
function getPublicIPv4Address
{
	local interface="$1"

	#	Note: there are numerous web services on the Internet that echo your current IPv4
	#	address using HTTP/HTTPS. Choose one you are compforable with.
	local ip="$(curl --url 'https://checkipv4.dedyn.io/' --silent --interface $interface)"

	#	Note: curl(8) needs to be installed manually (pkg_add curl) on OpenBSD. If you
	#	don't want to use curl(8) you could use the built-in ftp(1) command. However
	#	choosing the outgoing interface requires the IP of the interface not the name.
	#	The following assumes that there is only one IPv4 address configured on the
	#	interface. If you have more, you may need to modify the code to choose the one
	#	you want. This code chooses the first one.
#	local ifip="$(ifconfig $interface|grep 'inet '|cut -d ' ' -f 2|head -1)"
#	local ip="$(ftp -o '-' -s $ifip 'https://checkipv4.dedyn.io/' 2>/dev/null)"

	echo "$ip"
}

#	Get the current IPv6 address prefix for a given interface.
#	Parameters:
#		interface	The interface for which to get the public IPv6 address prefix
function getIPv6Prefix
{
	local interface="$1"
	
	#	route -n show -inet6 | grep $interface = List all IPv6 networks.
	#	grep '::/' = List only network addresses.
	#	grep -vE '^(fd|fe80)' = Remove ULA and link-local networks.
	#	awk -F '::/' '{print substr($1,1,19)}' = Shorten to the prefix.
	#	sort -u = Remove duplicates.
	#	tail -n 1 = Newer networks are listed at the bottom.
	#				Last entry therefore is the current IPv6 prefix.
	local publicIPv6Net=`route -n show -inet6 | grep -E '.+::/[1-9].+ '"$interface" \
		| grep -vE '^(fd|fe80)' \
		| awk -F '::/' '{print substr($1,1,19)}' \
		| sort -u | tail -n 1`

	echo "$publicIPv6Net"
}

#	Parameters:
#		interface	The interface for which the public IPv6 address prefix changed.
#		newPrefix	The new public IPv6 address prefix.
#		lastPrefix	The previous public IPv6 address prefix.
function prefixChanged
{
	local interface="$1"
	local newPrefix="$2"
	local lastPrefix="$3"
	
	printMessage "IPv6 prefix for ${interface} changed from [${lastPrefix}] to [${newPrefix}]"

	local changeAction="${CHANGEACTIONPATH}${interface}"

	if [ -f "$changeAction" ]; then
		. "$changeAction"
	else
		printDebug "File ${changeAction} not found. No action taken."
	fi
}


#	Parameters:
#		interface	The interface for which to get the public IPv6 address prefix
function handleInterface
{
	local interface="$1"
	local newPrefix=`getIPv6Prefix "$interface"`

	printDebug "IPv6 prefix for ${interface}: ${newPrefix}"

	[ -z "$newPrefix" ] && exit

	local cachePath="${CACHEFILE}${interface}"
	local lastPrefix=''
	[ -f "$cachePath" ] && lastPrefix="$(cat ${cachePath})"
	printDebug "Last IPv6 prefix: ${lastPrefix}"

	if [ "$newPrefix" != "$lastPrefix" ]; then
		echo "$newPrefix" > "$cachePath"
		prefixChanged "$interface" "$newPrefix" "$lastPrefix"
	fi
}


#
#	Main:
#

delayAfterBoot

handleInterface 'em0'
#handleInterface 'em1'


#
#	EOF.
#
