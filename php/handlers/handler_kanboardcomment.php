<?php 
require "JSONclient.php";
require_once 'vendor/autoload.php';


$client = new JsonRPC\Client('http://10.1.1.4/jsonrpc.php');
$client->authentication('jsonrpc', getenv('KB_APIKEY'));


function kanboardtask_add_comment($selected_kanboard,$selected_kanboardtask, $taskline,$content)
{
if (strlen($content)== 0) return;
if ($selected_kanboard== 0) return;
if ($selected_kanboardtask== 0) return;

	global $client;
	$cc = str_replace('\n','\n\n',$content);
	
	$newtaskparams = array(
		"task_id" => $selected_kanboardtask,
		"user_id" => 20 ,
		"content" => $cc

	 );
	try
	{
		$task = $client->createComment($newtaskparams);	
	} 
	catch (Exception $e) {
		print $e->getMessage();
    	return '';
    }
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


$comment=implode(' ' , $argv);
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
				kanboardtask_add_comment($selected_kanboard,$task["id"],'',$comment);
				$found = true;
				$taskid = $task["id"];
			}
		
	}
}

if (!$found)
{
	print "Sorry, I cannot find a kanboard task for $shortname";
} else
{
 print "Comment added to kanboard task. https://kanboard.radicallyopensecurity.com/project/" . $selected_kanboard . "/task/" . $taskid . "#comments ";
}


