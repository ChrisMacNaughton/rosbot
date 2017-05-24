<?php 
require "JSONclient.php";
require_once 'vendor/autoload.php';


$client = new JsonRPC\Client('http://10.1.1.4/jsonrpc.php');
$client->authentication('jsonrpc', getenv('KB_APIKEY'));



function cmp($a, $b)
{
    if ($a["id"] == $b["id"]) {
        return 0;
    }
    return ($a["id"] > $b["id"]) ? -1 : 1;
}




$m = new MongoClient("mongodb://10.1.1.4:3001");
// select a database
$db = $m->meteor;

// select a collection (analogous to a relational database's table)
$collection = $db->rocketchat_room;

// find everything in the collection
$cursor = $collection->find( array('_id' => $argv[1]) );
$room = $cursor->getNext();
$channelname = $room['name'];

//print "1: " . $argv[1];
//print "2: " . $argv[2];
//print "3: " . $argv[3];
//print "4: " . $argv[4];
unset($argv[0]);
unset($argv[1]);
unset($argv[2]);
unset($argv[3]);

$tasklist = array();


$commentcount=0+implode(' ' , $argv);
$selected_kanboard = 0;
$shortname=$channelname;
if (substr($channelname,0,4) == "off-") 
{
 	$shortname = substr($channelname,4,999);
	$tasklist = $client->getAllTasks(2,1);
	$selected_kanboard = 2;

}
if (substr($channelname,0,4) == "pen-")
{
 	$shortname = substr($channelname,4,999);
	$tasklist = $client->getAllTasks(1,1);
	$selected_kanboard = 1;

}
$found = false;
$taskid = 0;
if (is_array($tasklist))
{
	foreach($tasklist as $task)
	{
			if (( $task["title"] == $shortname) or ($task["title"] == $channelname) )
			{

				$found = true;
				$taskid = $task["id"];
				
				$commentslist = $client->getAllComments($taskid);
				usort($commentslist,"cmp");
				$x=0;
				foreach( $commentslist as $comment)
				{
					if ($x<$commentcount) print($comment['comment']);
					$x++;

				}
				
			}
		
	}
}

if (!$found)
{
	print "Sorry, I cannot find a kanboard task for $shortname";
} else
{
 print "Comments from kanboard task https://kanboard.radicallyopensecurity.com/project/" . $selected_kanboard . "/task/" . $taskid . "#comments ";
}


