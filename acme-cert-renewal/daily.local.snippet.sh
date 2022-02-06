#	Copyright (c)2021-2022 by fiwswe
#
#	Insert this into /etc/daily.local or include it from there.
#	Or you could add the #!/bin/sh line at the top and start the script via cron(8). But
#	you might need to check whether logging and mail notifications work as expected then.
#

#
# Renew the Let's Encrypt certificates on this server (if necessary):
#

DO_ACTION=1
NO_ACTION=0

NEED_HTTPD_RESTART=$NO_ACTION
NEED_APACHE_RESTART=$NO_ACTION
NEED_DOVECOT_RESTART=$NO_ACTION
NEED_SMTPD_RESTART=$NO_ACTION
NEED_POSTFIX_RESTART=$NO_ACTION
ERROR_DOMAINS=''

#	Parameters:
#		domain		The main domain for the certificate.
function addErrorDomain
{
	if [ $# -ge 1 ];then
		if [ -z "$ERROR_DOMAINS" ]; then
			ERROR_DOMAINS="$1"
		else
			ERROR_DOMAINS="${ERROR_DOMAINS}, $1"
		fi
	fi
}

#	Parameters:
#		domain		The main domain for the certificate.
#		needHttpd	'HTTPD' if OpenBSD httpd depends on the certificate.
#		needApache	'APACHE' if Apache depends on the certificate.
#		needHttpd	'HTTPD' if OpenBSD httpd depends on the certificate.
#		needDovecot	'DOVECOT' if Dovecot depends on the certificate.
#		needSMTPd	'SMTPD' if smtpd depends on the certificate.
#		needPostfix	'POSTFIX' if Postfix depends on the certificate.
#	Note: Unneeded parameters can be omitted from the end but if e.g.
#		  'DOVECOT' is present then placeholders for 'APACHE' and 'HTTPD'
#		  must also be present (with different values).
#	Examples:
#		handleDomain example.com 'HTTPD' 'NO_APACHE'
#		handleDomain example.com 'NO_HTTPD' 'NO_APACHE' 'DOVECOT'
#		handleDomain example.com 'HTTPD'
function handleDomain
{
	if [ $# -ge 1 ];then
		/usr/sbin/acme-client "$1"
		case "$?" in
		0)	echo "Certificate for $1 was renewed."
			if [ $# -ge 2 -a "$2" = 'HTTPD' ];then
				NEED_HTTPD_RESTART=$DO_ACTION
			fi
			if [ $# -ge 3 -a "$3" = 'APACHE' ];then
				NEED_APACHE_RESTART=$DO_ACTION
			fi
			if [ $# -ge 4 -a "$4" = 'DOVECOT' ];then
				NEED_DOVECOT_RESTART=$DO_ACTION
			fi
			if [ $# -ge 5 -a "$5" = 'SMTPD' ];then
				NEED_SMTPD_RESTART=$DO_ACTION
			fi
			if [ $# -ge 6 -a "$6" = 'POSTFIX' ];then
				NEED_POSTFIX_RESTART=$DO_ACTION
			fi
			;;
		1)	addErrorDomain "$1"
			;;
		2)	echo "Certificate for $1 does not need to be renewed."
			;;
		*)	echo "Unknown error ($?) while trying to renew certificate for $1!"
			addErrorDomain "$1"
			;;
		esac
	else
		echo 'ERROR: No domain for certificate renewal check!'
	fi
}


#
# Handle the certificates:
#

handleDomain mail.example.com 'NO_HTTPD' 'NO_APACHE' 'DOVECOT' 'SMTPD'

handleDomain www.example.com 'NO_HTTPD' 'APACHE'

handleDomain wiki.example.com 'HTTPD'


#
# Now do any needed actions (only once, even if triggered more than once above):
#

# Handle httpd(8):
if [ $NEED_HTTPD_RESTART -ne $NO_ACTION ]; then
	/usr/sbin/rcctl restart httpd
fi

# Handle Apache httpd2(8):
if [ $NEED_APACHE_RESTART -ne $NO_ACTION ]; then
	/usr/local/sbin/apachectl restart
	# As an example, deal with failures: Sometimes restarting the Apache httpd fails for some reason. Try again…
	if [ $? -ne 0 ]; then
		sleep 1
		/usr/local/sbin/apachectl restart
		if [ $? -ne 0 ]; then
			echo 'ERROR: Could not restart Apache after certificate update! (Tried and failed twice...)'|mail -s '`hostname` Apache restart failure' root
		fi
	fi
fi

# Handle dovecot(1):
if [ $NEED_DOVECOT_RESTART -ne $NO_ACTION ]; then
	/usr/sbin/rcctl restart dovecot
fi

# Handle smtpd(8):
if [ $NEED_SMTPD_RESTART -ne $NO_ACTION ]; then
	/usr/sbin/rcctl restart smtpd
fi

# Handle postfix(1):
if [ $NEED_POSTFIX_RESTART -ne $NO_ACTION ]; then
	/usr/sbin/rcctl restart postfix
fi

if [ -n "$ERROR_DOMAINS" ]; then
	echo "ERROR updating certificates for ${ERROR_DOMAINS}!"
	echo "ERROR updating certificates for ${ERROR_DOMAINS}!"|mail -s "`hostname` Certificate renewal errors" root
fi


#
# Done with the Let's Encrypt certificate renewal.
#
