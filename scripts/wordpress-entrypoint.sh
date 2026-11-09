#!/bin/sh
set -eu

if [ -e /var/www/html/wp-includes/version.php ]; then
    installed_version="$(php -r 'require "/var/www/html/wp-includes/version.php"; echo $wp_version;')"
    image_version="$(php -r 'require "/usr/src/wordpress/wp-includes/version.php"; echo $wp_version;')"
    if [ "$installed_version" != "$image_version" ]; then
        printf 'WordPress volume version %s does not match image version %s. Select matching volumes or reset this preset.\n' \
            "$installed_version" "$image_version" >&2
        exit 1
    fi
fi

if [ ! -e /var/www/html/index.php ]; then
    cp -a /usr/src/wordpress/. /var/www/html/
fi

if [ ! -e /var/www/html/wp-config.php ]; then
    cat > /var/www/html/wp-config.php <<'PHP'
<?php
define('DB_NAME', getenv('WORDPRESS_DB_NAME'));
define('DB_USER', getenv('WORDPRESS_DB_USER'));
define('DB_PASSWORD', getenv('WORDPRESS_DB_PASSWORD'));
define('DB_HOST', getenv('WORDPRESS_DB_HOST'));
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');
define('AUTH_KEY',         'php2shell-research-auth-key');
define('SECURE_AUTH_KEY',  'php2shell-research-secure-auth-key');
define('LOGGED_IN_KEY',    'php2shell-research-logged-in-key');
define('NONCE_KEY',        'php2shell-research-nonce-key');
define('AUTH_SALT',        'php2shell-research-auth-salt');
define('SECURE_AUTH_SALT', 'php2shell-research-secure-auth-salt');
define('LOGGED_IN_SALT',   'php2shell-research-logged-in-salt');
define('NONCE_SALT',       'php2shell-research-nonce-salt');
$table_prefix = 'wp_';
define('AUTOMATIC_UPDATER_DISABLED', true);
define('WP_AUTO_UPDATE_CORE', false);
$php2shell_site_url = getenv('WORDPRESS_SITE_URL');
if ($php2shell_site_url) {
    define('WP_HOME', $php2shell_site_url);
    define('WP_SITEURL', $php2shell_site_url);
}
if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}
require_once ABSPATH . 'wp-settings.php';
PHP
fi

chown -R www-data:www-data /var/www/html

if [ "${1:-}" = apache2-foreground ]; then
    php2shell-apache-workers
fi

exec "$@"
