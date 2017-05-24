<?php

error_reporting(E_ALL);

# Read input from hubot.

$channelID = $argv[1];
if (!preg_match('/^[A-Za-z0-9_-]*$/', $channelID))
{
    echo 'Parameters contain illegal character.';
    exit(1);
}

$callerID = $argv[2];
if (!preg_match('/^[A-Za-z0-9_-]*$/', $callerID))
{
    echo 'Parameters contain illegal character.';
    exit(1);
}

# Include library code.

require_once(dirname(__FILE__) . '/inc/squirrel.php');

define('INFRACODE', '/opt/rosbot/infracode');
require_once(INFRACODE . '/php/log.php');
require_once(INFRACODE . '/php/triad.php');
require_once(INFRACODE . '/php/gitlab.php');
require_once(INFRACODE . '/php/kanboard.php');
require_once(INFRACODE . '/php/user.php');
require_once(INFRACODE . '/php/rosbot.php');

# Set up logging.

$log = new \Monolog\Logger('rosbot-shipit');
$formatter = new \Monolog\Formatter\LineFormatter("> %message%\n");
$handler = new \Monolog\Handler\ErrorLogHandler();
$handler->setFormatter($formatter);
$handler->setLevel(\Monolog\Logger::INFO);
$log->pushHandler($handler);
GlobalLog::$log = $log;


# Send congratulatory squirrel.
squirrel();

# Look up triad corresponding to current channel.
try
{
    $triad = Triad::fromRoomID($channelID);
}
catch (Exception $e)
{
    $log->debug('Shipit could not find triad: ' . $e->getMessage());
    exit(1);
}
if ($triad->type != 'pen')
{
    $log->debug('The current channel (ID ' . $channelID . ') does not correspond to a known pentest.');
    exit(1);
}


$kbclient = GlobalKanboardClient::$client;
$task = KanboardTask::fromID($triad->kanboardTaskID);

# Look up relevant users.
$arie = KanboardUser::fromName('ariepeterson');
$caller = RosUser::fromRocketchatID($callerID);
$caller = KanboardUser::fromName($caller->username);

# Add subtasks.
$log->info('Adding tasks to kanboard...');
$task->addSubtask($kbclient, 'Archive internal project data', $arie->ID, true);
$task->addSubtask($kbclient, 'Send invoice to financial team (rosbot sendinvoice)', $caller->ID, true);

# Move kanboard task.
$log->info('Moving kanboard task to "Finishing".');
$task->move($kbclient, 'Finishing');

# Notify project management.
$msg = $caller . ' says that project *' . $triad->alias() . '* has shipped!' . PHP_EOL
  . 'See chat: ' . $triad->chatURL() . PHP_EOL
  . 'Now may be a good time to let the financial team know that the invoice for this pentest can be sent.' . PHP_EOL
  . 'You could use `rosbot sendinvoice ' . $triad->name . '` to notify them.';
tell_rosbot($msg, 'ros-projectmanagement');

?>
