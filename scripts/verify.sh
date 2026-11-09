#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
docker compose "$@" config --quiet

configured_services="$(docker compose "$@" config --services)"
running_services="$(docker compose "$@" ps --services --status running)"
is_running() {
    printf '%s\n' "$running_services" | grep -qx "$1"
}
is_configured() {
    printf '%s\n' "$configured_services" | grep -qx "$1"
}

target_count=0
for service in wp-fpm-a wp-fpm-b wp-apache; do
    if is_configured "$service"; then target_count=$((target_count + 1)); fi
done
if [ "$target_count" -eq 0 ]; then
    printf 'No PHP target profile selected for verification\n' >&2
    exit 1
fi

setup_services=""
for service in setup-fpm-a setup-fpm-b setup-apache; do
    if is_configured "$service"; then setup_services="$setup_services $service"; fi
done
if [ -n "$setup_services" ]; then
    attempt=0
    while :; do
        setup_status="$(docker compose "$@" ps -a --format json $setup_services | python3 -c '
import json, sys
services = {s["Service"]: s for s in (json.loads(line) for line in sys.stdin if line.strip())}
if any(s["State"] == "exited" and s["ExitCode"] != 0 for s in services.values()):
    for service in services.values():
        print("{}: {} (exit {})".format(service["Service"], service["State"], service["ExitCode"]), file=sys.stderr)
    sys.exit(1)
print("ready" if len(services) == len(sys.argv[1:]) and all(s["State"] == "exited" for s in services.values()) else "waiting")
' $setup_services)"
        [ "$setup_status" = ready ] && break
        if [ "$attempt" -ge 120 ]; then
            printf 'WordPress setup did not finish within 120 seconds\n' >&2
            exit 1
        fi
        attempt=$((attempt + 1))
        sleep 1
    done
fi

for service in wp-fpm-a wp-fpm-b wp-apache; do
    if is_configured "$service" && ! is_running "$service"; then
        printf '%s is configured but not running\n' "$service" >&2
        exit 1
    fi
done

printf '%-12s %-9s %-9s %-24s %-12s %s\n' TARGET PHP WORDPRESS WEB_SAPI MEMORY_LIMIT UPLOAD_PROGRESS
for service in wp-fpm-a wp-fpm-b; do
    is_running "$service" || continue
    values="$(docker compose "$@" exec -T "$service" php -r \
        'require "/var/www/html/wp-includes/version.php"; echo PHP_VERSION, " ", $wp_version, " fpm/FastCGI ", ini_get("memory_limit"), " ", ini_get("session.upload_progress.enabled");')"
    printf '%-12s %s\n' "$service" "$values"
done

if is_running wp-apache; then
    values="$(docker compose "$@" exec -T wp-apache sh -c \
        'apache2ctl -M 2>/dev/null | grep -q php_module && php -r '\''require "/var/www/html/wp-includes/version.php"; echo PHP_VERSION, " ", $wp_version, " apache2handler(mod_php) ", ini_get("memory_limit"), " ", ini_get("session.upload_progress.enabled");'\''')"
    printf '%-12s %s\n' wp-apache "$values"
    docker compose "$@" exec -T wp-apache sh -c \
        "apache2ctl -t >/dev/null && grep -E 'StartServers|MinSpareServers|MaxSpareServers|MaxRequestWorkers|MaxConnectionsPerChild' /etc/apache2/conf-enabled/php2shell-workers.conf"
fi

for service in wp-fpm-a wp-fpm-b wp-apache; do
    is_running "$service" || continue
    expected="$(docker compose "$@" config --format json | python3 -c '
import json, sys
service = json.load(sys.stdin)["services"][sys.argv[1]]
base = service["build"]["args"]["PHP_BASE_IMAGE"]
print(base.split(":", 1)[1].split("-", 1)[0], service["build"]["args"]["WORDPRESS_VERSION"])
' "$service")"
    actual="$(docker compose "$@" exec -T "$service" php -r \
        'require "/var/www/html/wp-includes/version.php"; echo PHP_VERSION, " ", $wp_version;')"
    if [ "$actual" != "$expected" ]; then
        printf '%s version mismatch: expected %s, got %s\n' "$service" "$expected" "$actual" >&2
        exit 1
    fi
done

for service in wp-fpm-a wp-fpm-b wp-apache; do
    is_running "$service" || continue
    docker compose "$@" exec -T "$service" php -r \
        '$s = @fsockopen("1.1.1.1", 80, $errno, $error, 1); if (is_resource($s)) { fclose($s); exit(1); }' \
        || { printf '%s unexpectedly has outbound access\n' "$service" >&2; exit 1; }
done
printf 'Running PHP targets have no ordinary outbound access.\n'

ports=""
if is_running gateway-fpm; then ports="${FPM_A_PORT:-18081} ${FPM_B_PORT:-18082}"; fi
if is_running gateway-apache; then ports="$ports ${APACHE_PORT:-18083}"; fi
for port in $ports; do
    code="$(curl --silent --output /dev/null --write-out '%{http_code}' --max-time 10 "http://127.0.0.1:$port/")"
    case "$code" in
        200) printf '127.0.0.1:%s HTTP %s OK\n' "$port" "$code" ;;
        *) printf '127.0.0.1:%s HTTP %s FAILED\n' "$port" "$code" >&2; exit 1 ;;
    esac
done

docker compose "$@" ps
