#!/bin/sh
set -eu

: "${APACHE_START_SERVERS:=1}"
: "${APACHE_MIN_SPARE_SERVERS:=1}"
: "${APACHE_MAX_SPARE_SERVERS:=4}"
: "${APACHE_MAX_REQUEST_WORKERS:=4}"
: "${APACHE_MAX_CONNECTIONS_PER_CHILD:=0}"

cat > /etc/apache2/conf-enabled/php2shell-workers.conf <<EOF
<IfModule mpm_prefork_module>
    StartServers ${APACHE_START_SERVERS}
    MinSpareServers ${APACHE_MIN_SPARE_SERVERS}
    MaxSpareServers ${APACHE_MAX_SPARE_SERVERS}
    MaxRequestWorkers ${APACHE_MAX_REQUEST_WORKERS}
    MaxConnectionsPerChild ${APACHE_MAX_CONNECTIONS_PER_CHILD}
</IfModule>
EOF
