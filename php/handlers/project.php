<?php

error_reporting(E_ALL);
define('INFRACODE', '/opt/rosbot/infracode');
require_once(INFRACODE . '/php/common-includes.php');

# Read input from hubot.

try
{
    array_shift($argv); # First element is the program name.
    $channelID    = verifyInput(array_shift($argv));
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
require_once(INFRACODE . '/php/triad.php');
require_once(INFRACODE . '/php/gitlab.php');
require_once(INFRACODE . '/php/kanboard.php');
require_once(INFRACODE . '/php/user.php');
require_once(INFRACODE . '/php/rosbot.php');
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

$hasAccess = userHasRole($caller, ROLE_PM) || userHasRole($caller, ROLE_SYSOP);
if (! $hasAccess)
{
    echo 'Sorry, you have no access to this command.';
    exit(1);
}

# Set up logging.

$log = new \Monolog\Logger('rosbot-project');
$formatter = new \Monolog\Formatter\LineFormatter("> %message%\n");
$handler = new \Monolog\Handler\ErrorLogHandler();
$handler->setFormatter($formatter);
$handler->setLevel(\Monolog\Logger::INFO);
$log->pushHandler($handler);
GlobalLog::$log = $log;

try
{
    $commandParts = explode(' ', $command);
    $principalCommand = array_shift($commandParts);
    switch ($principalCommand)
    {
        case 'status':
            $set = array_search('set', $commandParts);
            if ($set !== false)
            {
                array_splice($commandParts, $set, 1); # Remove 'set' from command.
                $alias = array_shift($commandParts);
                $triad = readTriad($alias);
                $status = implode(' ', $commandParts);
                setProjectStatus($triad, $status);
            }
            else
            {
                $target = array_shift($commandParts);
                projectStatus($target, $commandParts);
            }
            break;
        case 'move':
            $alias = array_shift($commandParts);
            $triad = readTriad($alias);
            # Assume that everything after the project name is the name of the
            # new column
            $column = implode(' ', $commandParts);
            projectMove($triad, $column);
            break;
        case 'hold':
            $alias = array_shift($commandParts);
            $triad = readTriad($alias);
            setProjectTag($triad, 'On hold', true);
            break;
        case 'unhold':
            $alias = array_shift($commandParts);
            $triad = readTriad($alias);
            setProjectTag($triad, 'On hold', false);
            break;
        case 'followup':
            $alias = array_shift($commandParts);
            $triad = readTriad($alias);
            setProjectTag($triad, 'Follow-up required', true);
            break;
        case 'nofollowup':
            $alias = array_shift($commandParts);
            $triad = readTriad($alias);
            setProjectTag($triad, 'Follow-up required', false);
            break;
        case 'assign':
            $alias = array_shift($commandParts);
            $triad = readTriad($alias);
            $user = array_shift($commandParts);
            $user = readUser($user);
            projectAssign($triad, $user);
            break;
        case 'unassign':
            $alias = array_shift($commandParts);
            $triad = readTriad($alias);
            projectAssign($triad, null);
            break;
        default:
            echo 'Command "' . $command . '" not known.';
    }
}
catch (Exception $e)
{
    echo 'rosbot project *failed*: ```' . $e->getMessage() . '```';
}

function projectMove($triad, $column)
{
    $log = GlobalLog::$log;
    $kbclient = GlobalKanboardClient::$client;

    $log->info('Moving project ' . $triad->alias() . ' to column "' . $column . '"');
    $task = KanboardTask::fromID($triad->kanboardTaskID);
    $task->move($kbclient, $column);
}

function setProjectStatus($triad, $status)
{
    $log = GlobalLog::$log;
    $kbclient = GlobalKanboardClient::$client;

    $log->info('Will set status of ' . $triad->name . ' to: ' . $status);
    $task = KanboardTask::fromID($triad->kanboardTaskID);
    $task->setStatusLine($kbclient, $status);
    $log->info('Done');
}

function setProjectTag($triad, $tag, $present)
{
    $log = GlobalLog::$log;
    $kbclient = GlobalKanboardClient::$client;

    $task = KanboardTask::fromID($triad->kanboardTaskID);
    switch ($present)
    {
        case true:
            $log->info('Adding tag "' . $tag . '" to ' . $triad->alias() . ' .');
            $task->addTag($tag);
            break;
        case false:
            $log->info('Removing tag "' . $tag . '" from ' . $triad->alias() . ' .');
            $task->removeTag($tag);
            break;
    }
}

function projectAssign($triad, $user)
{
    $log = GlobalLog::$log;
    $kbclient = GlobalKanboardClient::$client;

    $task = KanboardTask::fromID($triad->kanboardTaskID);
    if (is_null($user))
    {
        $log->info('Unassigning ' . $task->title);
    }
    else
    {
        $log->info('Assigning ' . $task->title . ' to ' . $user->name);
    }
    $task->assign($kbclient, $user);
}

function projectStatus($target, $commandParts)
{
    $log = GlobalLog::$log;
    $kbclient = GlobalKanboardClient::$client;

    # Determine what project(s) we want the status of.
    switch ($target)
    {
        case Triad::OFF:
            projectStatusType(Triad::OFF);
            break;
        case Triad::PEN:
            projectStatusType(Triad::PEN);
            break;
        case 'test':
            projectStatusType('test');
            break;
        case 'onhold':
        case 'on':
            projectStatusType(Triad::OFF, true);
            break;
        case 'followup':
        case 'follow-up':
            projectStatusType(Triad::OFF, false, true);
            break;
        case 'all':
        case '':
            projectStatusType(Triad::OFF);
            projectStatusType(Triad::PEN);
            break;
        default:
            projectStatusAlias($target);
    }
}

function projectStatusType($type, $onHold = false, $followup = false)
{
    $log = GlobalLog::$log;
    $kbclient = GlobalKanboardClient::$client;

    $log->info('*' . $type . '*:');
    $board = KanboardProject::fromType($type);
    $hiddenColumns = hiddenColumns($type);
    $hiddenColumnIDs = array();
    foreach ($hiddenColumns as $c)
    {
        $hiddenColumnIDs[] = $board->lookupColumn($c)['id'];
    }
    $log->info('(hiding columns: ' . implode(', ', $hiddenColumns) . ')');
    if ($onHold)
    {
        $log->info('(only showing projects on hold)');
    }
    else
    {
        $log->info('(hiding projects on hold)');
    }
    if ($followup)
    {
        $log->info('(only showing projects with follow-up required)');
    }
    $tasks = $kbclient->getAllTasks($type);
    foreach ($tasks as $task)
    {
        # Filter out tasks in certain columns.
        if (in_array($task->columnID, $hiddenColumnIDs))
        {
            continue;
        }

        $tags = $task->getTags();

        # Filter out, or only show, tasks that are on hold.
        if ($onHold != hasTagStarting('on hold', $tags))
        {
            continue;
        }

        if ($followup && ! hasTagStarting('follow-up', $tags))
        {
            # Only show tasks that have the followup tag.
            continue;
        }

        if (is_null($task->statusLine))
        {
            $status = '_no status set_';
        }
        else
        {
            $status = $task->statusLine;
        }
        $tagsString = implode(' ', array_map(function($tag) { return '`' . $tag . '`'; }, $tags));
        if (! is_null($task->assignee))
        {
            $kbuser = KanboardUser::fromID($task->assignee);
            $tagsString = '| assigned to *' . $kbuser->name . '* ' . $tagsString;
        }
        $log->info($task->title . ': ' . $status . ' ' . $tagsString);
    }
}

function projectStatusAlias($alias)
{
    $log = GlobalLog::$log;
    $kbclient = GlobalKanboardClient::$client;

    $triad = readTriad($alias);
    $task = KanboardTask::fromID($triad->kanboardTaskID);
    if (is_null($task->statusLine))
    {
        $status = '_no status set_';
    }
    else
    {
        $status = $task->statusLine;
    }
    $log->info('Status of *' . $triad->alias() . '*: ' . $status);
    $proj = KanboardProject::fromID($task->projID);
    $column = $proj->columnByID($task->columnID);
    $log->info('Column: ' . $column['title']);
    if (! is_null($task->assignee))
    {
        $kbuser = KanboardUser::fromID($task->assignee);
        $log->info('Assigned to *' . $kbuser->name . '*');
    }
    $tags = $task->getTags();
    foreach ($tags as $tag)
    {
        $log->info('`' . $tag . '`');
    }
}

function readTriad($alias)
{
    global $channelID;

    if ($alias == 'this')
    {
        try
        {
            $triad = Triad::fromRoomID($channelID);
            return $triad;
        }
        catch (Exception $e)
        {
            throw new Exception('The current channel does not correspond to a known project.' . PHP_EOL . $e->getMessage());
        }
    }
    else
    {
        # Look up triad.
        try
        {
            $triad = Triad::fromAlias($alias);
            return $triad;
        }
        catch (Exception $e)
        {
            throw new Exception('The specified project could not be found.' . PHP_EOL . $e->getMessage());
        }
    }
}

function readUser($username)
{
    global $caller;

    if ($username == 'me')
    {
        $rosUser = $caller;
    }
    else
    {
        try
        {
            $rosUser = RosUser::fromRocketchatName($username);
        }
        catch (Exception $e)
        {
            throw new Exception('The chat name "' . $username . '" was not found in the database.' . PHP_EOL . $e->getMessage());
        }
    }

    $kanboardUser = KanboardUser::fromName($rosUser->username);
    return $kanboardUser;
}

function hiddenColumns($type)
{
    switch ($type)
    {
        case Triad::OFF:
            $hiddenColumns = array(
              'Shipped',
              'Accepted',
              'Rejected',
              'Done'
            );
            break;
        case Triad::PEN:
            $hiddenColumns = array(
              'Finishing',
              'Done'
            );
            break;
        default:
           $hiddenColumns = array();
    }
    return $hiddenColumns;
}

function hasTagStarting($string, $tags)
{
    foreach ($tags as $tag)
    {
        if (preg_match('/^' . $string . '/i', $tag))
        {
            return true;
        }
    }
    return false;
}

?>
