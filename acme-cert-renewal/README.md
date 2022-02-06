# acme certificate renewal

When using [acme-client(1)](https://man.openbsd.org/acme-client) it is seemingly very easy to renew certificates: Just call `acme-client <domain>` on a regular bases, such as from `/etc/daily.local` or from a [cron(8)](https://man.openbsd.org/cron) job.

While not incorrect this does not solve the problem of getting running services to use the updated certificates. Doing this on a host that use a number of services and a number of different certifictaes gets tedious quickly. Also you might reload e.g. a web server several times when multiple certificates are updated which is unnecessary. And you may want to be notified when certificates change or when something goes wrong.

The shell script snippet is meant to be added to or included from `/etc/daily.local`. It reduces the custom code for each certificate to one line which specifies the hostname and the affected services. For example:
```
handleDomain www.example.com 'HTTPD'
handleDomain mail.example.com 'NO_HTTPD' 'NO_APACHE' 'SMTPD' 'DOVECOT'
```

The script snippet will also log what it does to the email sent by the [daily(8)](https://man.openbsd.org/daily) mechanism and to `/var/log/daily.out`.

Adding additional services should be fairly easy. Just follow the pattern of the example services provided in the code.
