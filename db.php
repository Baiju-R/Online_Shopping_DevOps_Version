<?php

$servername = "db";   // ✅ Kubernetes service name
$username = "root";
$password = "root";
$db = "onlineshop";

$con = mysqli_connect($servername, $username, $password, $db);

if (!$con) {
    die("Connection failed: " . mysqli_connect_error());
}

?>