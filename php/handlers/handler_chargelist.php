<?php 
require "JSONclient.php";
require_once 'vendor/autoload.php';

$month = date('n');


$sql = "select user, registration_date, hours ,description, channel from registration 
where  ( month(registration_date) = month(now())    or (  month(registration_date) = month(TIMESTAMPADD(month,-1,now())) ) )  
order by user, channel, registration_date";


	$db = new PDO('mysql:host=localhost;dbname=hours;charset=utf8mb4', 'nginx', getenv('MYSQL_PASSWORD'));
	$stmt = $db->prepare($sql);
	$result = $stmt->execute();

$total=0;
$olduser = "";
$oldchannel = "";
$descriptions = "";


 while ($row = $stmt->fetch(PDO::FETCH_BOTH)) {
 
 	if (($olduser <>  $row['user']) or ($oldchannel <>  $row['channel']))
 	{
 		if ($total >0)
 		{
			print $olduser . " charged " . $total .  " for " . $oldchannel . ":  " . $descriptions . " \n";
			$total=0;
			$olduser = $row['user'];
			$oldchannel = $row['channel'];
			$descriptions = $row['description'];
 		} 
 	}
	$total +=  $row['hours'];
	$descriptions .= " " .  $row['description'];
	
 

}
