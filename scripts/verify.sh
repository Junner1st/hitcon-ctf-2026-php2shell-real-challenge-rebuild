#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
docker compose config --quiet

running_services="$(docker compose ps --services --status running)"
is_running() {
    printf '%s\n' "$running_services" | grep -qx "$1"
}

printf '%-12s %-9s %-9s %-24s %-12s %s\n' TARGET PHP WORDPRESS WEB_SAPI MEMORY_LIMIT UPLOAD_PROGRESS
for service in wp-fpm-a wp-fpm-b; do
    is_running "$service" || continue
    values="$(docker compose exec -T "$service" php -r \
        'require "/var/www/html/wp-includes/version.php"; echo PHP_VERSION, " ", $wp_version, " fpm/FastCGI ", ini_get("memory_limit"), " ", ini_get("session.upload_progress.enabled");')"
    printf '%-12s %s\n' "$service" "$values"
done

if is_running wp-apache; then
    values="$(docker compose exec -T wp-apache sh -c \
        'apache2ctl -M 2>/dev/null | grep -q php_module && php -r '\''require "/var/www/html/wp-includes/version.php"; echo PHP_VERSION, " ", $wp_version, " apache2handler(mod_php) ", ini_get("memory_limit"), " ", ini_get("session.upload_progress.enabled");'\''')"
    printf '%-12s %s\n' wp-apache "$values"
    docker compose exec -T wp-apache sh -c \
        "apache2ctl -t >/dev/null && grep -E 'StartServers|MinSpareServers|MaxSpareServers|MaxRequestWorkers|MaxConnectionsPerChild' /etc/apache2/conf-enabled/php2shell-workers.conf"
fi

for service in wp-fpm-a wp-fpm-b wp-apache; do
    is_running "$service" || continue
    docker compose exec -T "$service" php -r \
        '$s = @fsockopen("1.1.1.1", 80, $errno, $error, 1); if (is_resource($s)) { fclose($s); exit(1); }' \
        || { printf '%s unexpectedly has outbound access\n' "$service" >&2; exit 1; }
done
printf 'Running PHP targets have no ordinary outbound access.\n'

set --
if is_running gateway-fpm; then set -- "$@" "${FPM_A_PORT:-18081}" "${FPM_B_PORT:-18082}"; fi
if is_running gateway-apache; then set -- "$@" "${APACHE_PORT:-18083}"; fi
for port do
    code="$(curl --silent --output /dev/null --write-out '%{http_code}' --max-time 10 "http://127.0.0.1:$port/")"
    case "$code" in
        2*|3*) printf '127.0.0.1:%s HTTP %s OK\n' "$port" "$code" ;;
        *) printf '127.0.0.1:%s HTTP %s FAILED\n' "$port" "$code" >&2; exit 1 ;;
    esac
done

docker compose ps
