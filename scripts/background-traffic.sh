#!/bin/sh
set -eu

seed="$(date +%s)"
: "${TRAFFIC_ORIGINS:=http://nginx-fpm-a http://nginx-fpm-b http://wp-apache}"

while :; do
    seed=$(( (1103515245 * seed + 12345) & 2147483647 ))
    case $((seed % 5)) in
        0) path='/' ;;
        1) path='/wp-login.php' ;;
        2) path='/wp-json/wp/v2/posts' ;;
        3) path='/?s=php2shell' ;;
        4) path='/wp-admin/admin-ajax.php?action=heartbeat' ;;
    esac

    for origin in $TRAFFIC_ORIGINS; do
        curl --silent --show-error --max-time 3 \
            --user-agent "hitcon-warmup/$((seed % 17))" \
            --output /dev/null "$origin$path" || true
    done

    sleep "0.$((seed % 8 + 2))"
done
