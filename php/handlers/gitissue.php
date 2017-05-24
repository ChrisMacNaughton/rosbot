<?php
require "JSONclient.php";
require_once 'vendor/autoload.php';

$room_id = $argv[1];


$issue_text= implode(' ',array_slice($argv ,6   ));

$m = new MongoClient("mongodb://10.1.1.4:3001");
$gitclient = new \Gitlab\Client('https://gitlabs.radicallyopensecurity.com/api/v3/'); // change here
$gitclient->authenticate(getenv('GITLAB_TOKEN'), \Gitlab\Client::AUTH_URL_TOKEN);

// select a database
$db = $m->meteor;

// select a collection (analogous to a relational database's table)
$collection = $db->rocketchat_room;

// add a record

// find everything in the collection
$cursor = $collection->find( array('_id' => $room_id) );
$room = $cursor->getNext();
$room_name = $room['name'];
print "[+] Hello room " . $room_name;
try {

	$projects = $gitclient->api('projects')->search($room_name);
}
catch (Exception $e) {
	print "I am sorry, I cannot find a git project' " . $room_name . "'";
	exit;
}

if (count($projects) == 0)
{
	print "I am sorry, I cannot find a git project' " . $room_name . "'";
	exit;
}

$project_id=0;
foreach($projects as $p)
{
	if ($p['name'] == $room_name)
	{
		$project_id = $p['id'];
	}
}
if ($project_id == 0)
{
	print "I am sorry, I cannot find a git project' " . $room_name . "'";
	exit;
}

$project = new \Gitlab\Model\Project($project_id, $gitclient);

$issue = $project->createIssue($issue_text, array(
  'description' => '(auto-created by rosbot)'
));
print " issue created";

?>
