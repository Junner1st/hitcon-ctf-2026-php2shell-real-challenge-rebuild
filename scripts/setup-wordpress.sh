#!/bin/sh
set -eu

: "${TARGET_PATH:?TARGET_PATH is required}"
: "${TARGET_URL:?TARGET_URL is required}"
: "${TARGET_TITLE:?TARGET_TITLE is required}"

until [ -f "$TARGET_PATH/wp-config.php" ]; do
    sleep 1
done

until php -r '
    $host = explode(":", getenv("WORDPRESS_DB_HOST"), 2);
    $db = @new mysqli($host[0], getenv("WORDPRESS_DB_USER"), getenv("WORDPRESS_DB_PASSWORD"), getenv("WORDPRESS_DB_NAME"), isset($host[1]) ? (int) $host[1] : 3306);
    exit($db->connect_errno ? 1 : 0);
'; do
    sleep 1
done

php /opt/lab/setup-wordpress.php
