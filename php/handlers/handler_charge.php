<?php 
require "JSONclient.php";
require_once 'vendor/autoload.php';

$channelname = $argv[1];
$user = $argv[2];
$hours = 0+$argv[3];
$description = $argv[4];

//print "1: " . $argv[1];
//print "2: " . $argv[2];
//print "3: " . $argv[3];
//print "4: " . $argv[4];

unset($argv[0]);
unset($argv[1]);
unset($argv[2]);

##if (isset($argv[3])) unset($argv[3]);
##if (isset($argv[4])) unset($argv[4]);
##if (isset($argv[5])) unset($argv[5]);
##if (isset($argv[6])) unset($argv[6]);

if ($hours == 0)
{
	print "please tell us how many hours to charge to " . $channelname;exit;
}


$sql = "insert into registration (user, registration_date, hours, channel,description) values (:user,now(),:hours,:channel,:description)";


	$db = new PDO('mysql:host=localhost;dbname=hours;charset=utf8mb4', 'nginx', getenv('MYSQL_PASSWORD'));
	$stmt = $db->prepare($sql);
	$params = array(
		':hours' => $hours,
		':user' => $user,
		':description' => $description,
		':channel' => $channelname
	);
	$stmt->execute($params);
print "Duly noted, thank you";
