<?php

error_reporting(E_ALL);
define('INFRACODE', '/opt/rosbot/infracode');
require_once(INFRACODE . '/php/common-includes.php');

# Read input from hubot.

try
{
    array_shift($argv); # First element is the program name.
    // $channelID    = verifyInput(array_shift($argv));
    $callerID     = verifyInput(array_shift($argv));
    $command      = verifyInput(array_shift($argv), INPUT_FREEFORM);
}
catch (Exception $e)
{
    echo $e->getMessage();
    exit(1);
}

# Include library code.

require_once(INFRACODE . '/php/log.php');
require_once(INFRACODE . '/php/rocketchat.php');
require_once(INFRACODE . '/php/gitlab.php');
require_once(INFRACODE . '/php/user.php');
require_once(INFRACODE . '/php/access-control.php');

# Access control.

try
{
    $caller = RosUser::fromRocketchatID($callerID);
}
catch (Exception $e)
{
    throw new Exception('I\'m sorry, your rocketchat ID was not found in the user database.' . PHP_EOL . $e->getMessage());
}

$hasAccess = userHasRole($caller, ROLE_SYSOP);
if (! $hasAccess)
{
    echo 'Sorry, you have no access to this command.';
    exit(1);
}

# Set up logging.

$log = new \Monolog\Logger('rosbot-roomexport');
$formatter = new \Monolog\Formatter\LineFormatter("> %message%\n");
$handler = new \Monolog\Handler\ErrorLogHandler();
$handler->setFormatter($formatter);
$handler->setLevel(\Monolog\Logger::INFO);
$log->pushHandler($handler);
GlobalLog::$log = $log;

# Perform command.

try
{
    $roomName = $command;
    $log->info('[+] Looking for room ' . $roomName . PHP_EOL);

    $rcclient = GlobalRocketchatClient::$client;
    try
    {
        $roomID = $rcclient->findChatroom($roomName);
    }
    catch (Exception $e)
    {
        $log->error('[-] Chat room not found: ```' . $e->getMessage() . '```');
        exit(1);
    }

    $history = $rcclient->getHistory($roomID);

    $log->info('[+] Found room with ' . count($history) . ' messages.');
    $log->info('[+] Formatting archive...');

    # Open temporary file to store the chat history.
    $tmpfname = tempnam("/tmp", "rosbot");
    $of = fopen($tmpfname, "w");

    # Walk through the list of messages in reverse order.
    for (end($history); key($history) !== null; prev($history))
    {
        $message = current($history);
        $username = isset($message->u->username) ? $message->u->username : '';
	fwrite($of, $message->ts . "\t" . $username . "\t" . $message->msg . PHP_EOL);
    }

    # Close temporary file.
    fclose($of);

    $glclient = GlobalGitlabClient::$client;
    $projectName = 'chatarchives';
    $projectNamespace = 'ros';
    try
    {
    	$projects = $glclient->api('projects')->search($projectName);
        $projectID = null;
        foreach($projects as $p)
        {
            if ($p['name'] == $projectName)
            {
                $projectID = $p['id'];
            }
        }
        if (is_null($projectID))
        {
            throw new Exception('no project found with name "' . $projectName . '" and namespace "' . $projectNamespace . '"');
        }
    }
    catch (Exception $e)
    {
    	$log->error('[-] I am sorry, I cannot find the git project for chat archives: ' . $e->getMessage());
    	exit;
    }

    $repo = new GitlabRepo($glclient, $projectID);

    $notename = date('Y-m-d_H_i') . '-' . $roomName  . '-chatlog.txt';
    try
    {
        $fileInfo = $repo->writeFile('/notes/' . $notename, file_get_contents($tmpfname), 'Chatlog created by rosbot');
    }
    catch (Exception $e)
    {
        $log->error('Committing to gitlab failed: ' . $e->getMessage());
        unlink($tmpfname);
        exit(1);
    }

    unlink($tmpfname);
    
    $project = $glclient->api('projects')->show($projectID);
    $url = $project['web_url'];
    $url = str_replace('http:', 'https:', $url) . '/blob/master/' . $fileInfo['file_path'];
    $log->info('[+] Done: ' . $url);
}
catch (Exception $e)
{
    echo 'rosbot roomexport *failed*: ```' . $e->getMessage() . '```';
}

?>
