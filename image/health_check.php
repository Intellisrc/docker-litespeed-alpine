<?php
// Flag to skip loading all wordpress:
define("HEALTH_CHECK", true);
// Load WordPress configuration file
require_once('wp-config.php');

// Test database connection
$mysqli = new mysqli(DB_HOST, DB_USER, DB_PASSWORD, DB_NAME);
if ($mysqli->connect_errno) {
    echo "Error: Failed to connect to database.";
    exit();
}

// Test WordPress installation
$headers = get_headers("http://localhost/", false, stream_context_set_default(
    array(
        'http' => array(
            'timeout' => 60
        )
    )
));
//var_dump($headers);
$code = isset($headers[0]) ? substr($headers[0], 9, 1) * 1 : 5;
if($code > 3) {
	echo "Error: Invalid response: $code";
	exit();
}

// Everything seems fine
echo "ok";
