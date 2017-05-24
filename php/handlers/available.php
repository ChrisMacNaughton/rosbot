<?php
$wanteddate = "";
$datetotest = date_create();
if (isset( $argv[1] ) )
{
	array_shift($argv);
	$wanteddate = implode(' ',$argv);
}
$wanteddate = str_replace(',',' ',$wanteddate);
$wanteddate = str_replace('rosbot','',$wanteddate);
$wanteddate = str_replace('availability','',$wanteddate);
$wanteddate = trim($wanteddate);



if (strlen($wanteddate) > 2)
{
	$t = strtotime($wanteddate);
	if ($t === false)
	{
		print "I cannot understand '" . $wanteddate . "'";
	} else
	{
		$datetotest = date_create($wanteddate);

	}

}

$datenow = new DateTime("now");


$datetoteststr = $datetotest->format('Y-m-d');

$weekday = $datetotest->format('w');
$weekfield= "sun";
switch ($weekday)
{
	case 0: $weekfield= "sun";break;
	case 1: $weekfield= "mon";break;
	case 2: $weekfield= "tue";break;
	case 3: $weekfield= "wed";break;
	case 4: $weekfield= "thur";break;
	case 5: $weekfield= "fri";break;
	case 6: $weekfield= "sat";break;

}
$weekstart = $datetotest;
while ($weekstart->format('w') <> 1)
{
	$weekstart->sub(new DateInterval('P1D'));
}


$weekstartstr = $weekstart->format('Y-m-d');
$db = new PDO('mysql:host=localhost;dbname=planning;charset=utf8mb4', 'nginx', getenv('MYSQL_PASSWORD'));


$sql = "select u.user_name,u.realname from rosbotuser.user u,
			planning.person_availability pa
		where pa.person_id = u.user_name and pa.$weekfield = 1 and pa.week_start = :weekstart";


$msg = "On " . $datetoteststr . ": ";
$domsg=false;
	
	
$params=  array ( ':weekstart' => $weekstartstr ) ;


$domsg =false;
$stmt = $db->prepare($sql);
$stmt->execute($params);
while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
	$domsg =true;
	$name = "";
	if ($row['realname'] <> '') 
	{ $name = $row['realname'];
	} else $name = $row['user_name'];



	$msg .= $name;
	$sql = "select pb.type,p.name from planning.project_booking pb, planning.project p
	where p.id = pb.project_id and pb.bookdate = :bookdate and pb.person_id = :person";
	$params=  array ( ':person' => $row['user_name']  , ':bookdate' =>$datetoteststr ) ;
	$stmt2 = $db->prepare($sql);
	$stmt2->execute($params);
	//var_dump($params);print $sql;
	$defaultmsgextra = ", ";
	while ($row2 = $stmt2->fetch(PDO::FETCH_ASSOC)) {
		switch ($row2['type'])
		{
			case 'pen': $defaultmsgextra = " (pentesting " . trim($row2['name']) . "), ";break;
			case 'rep': $defaultmsgextra = " (reportwriting " . trim($row2['name']) . "), ";break;
			case 'off': $defaultmsgextra = " (offertewriting " . trim($row2['name']) . "), ";break;
		}
	}
	$msg .= $defaultmsgextra;
}
if (!$domsg)
{
	$msg .= " no known availability";
}
print $msg;

?>
