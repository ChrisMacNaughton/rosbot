<?php 
require "JSONclient.php";
require_once 'vendor/autoload.php';



$m = new MongoClient("mongodb://10.1.1.4:3001");
// select a database
$db = $m->meteor;

// select a collection (analogous to a relational database's table)
$collection = $db->rocketchat_room;

// find everything in the collection
$cursor = $collection->find( array('_id' => $argv[1]) );
$room = $cursor->getNext();
if (!is_array($room))
{
	print "Cannot find a channel name";exit;
}
$channelname = $room['name'];
$user = $argv[2];
$hours = 0+$argv[5];

//print "1: " . $argv[1];
//print "2: " . $argv[2];
//print "3: " . $argv[3];
//print "4: " . $argv[4];
unset($argv[0]);
unset($argv[1]);
unset($argv[2]);
unset($argv[3]);
unset($argv[4]);
unset($argv[5]);


$description= implode(' ' , $argv);
if ($hours == 0)
{
	print "please tell us how many hours to charge to this channel";exit;
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
