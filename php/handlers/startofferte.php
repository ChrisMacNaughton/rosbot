<?php

define('INFRACODE', '/opt/rosbot/infracode');

require_once(INFRACODE . '/php/common-includes.php');
require_once(INFRACODE . '/php/log.php');
require_once(INFRACODE . '/php/start.php');
require_once(INFRACODE . '/php/triad.php');

$projectName = $argv[1];

$log = new \Monolog\Logger('rosbot-startofferte');
$formatter = new \Monolog\Formatter\LineFormatter("> %message%\n");
$handler = new \Monolog\Handler\ErrorLogHandler();
$handler->setFormatter($formatter);
$handler->setLevel(\Monolog\Logger::INFO);
$log->pushHandler($handler);
GlobalLog::$log = $log;

try
{
    startproject(Triad::OFF, $projectName);
}
catch (Exception $e)
{
    $log->error('Starting new project failed: ' . $e->getMessage());
}

?>
