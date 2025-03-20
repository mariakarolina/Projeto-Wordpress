<?php
define('DB_NAME', 'wordpress');
define('DB_USER', 'admin');
define('DB_PASSWORD', '202019Mara.');
define('DB_HOST', 'wordpressbd.c9cweqmayjz8.us-east-1.rds.amazonaws.com');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');
define('FS_METHOD', 'direct');

$table_prefix = 'wp_';

define('WP_DEBUG', true);
if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}
require_once ABSPATH . 'wp-settings.php';
