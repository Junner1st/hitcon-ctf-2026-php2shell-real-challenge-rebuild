<?php

$targetPath = getenv('TARGET_PATH');
$targetUrl = getenv('TARGET_URL');
$targetTitle = getenv('TARGET_TITLE');

chdir($targetPath);
define('WP_INSTALLING', true);
require $targetPath . '/wp-load.php';
require_once $targetPath . '/wp-admin/includes/upgrade.php';

if (!is_blog_installed()) {
    wp_install(
        $targetTitle,
        'admin',
        'lab@example.invalid',
        true,
        '',
        'hitcon-lab-only'
    );
}

update_option('home', $targetUrl);
update_option('siteurl', $targetUrl);
update_option('blogdescription', 'php2shell isolated reproduction target');

if (!is_blog_installed()) {
    fwrite(STDERR, "WordPress installation did not complete.\n");
    exit(1);
}
