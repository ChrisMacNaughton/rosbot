# Description:
#   Project management commands
#
# Dependencies:
#   None
#
# Configuration:
#
# Commands:
#   project status [projectName|projectType] - Show status line of project(s)
#
# Author:
#   ariep

module.exports = (robot) ->

  run_cmd = (cmd, args, cb ) ->
    spawn = require("child_process").spawn
    child = spawn(cmd, args)
    child.stdout.on "data", (buffer) -> cb buffer.toString()
    child.stderr.on "data", (buffer) -> cb buffer.toString()

  robot.respond /project \s*(.*)/i, id:'chatops.project', (msg) ->
    cmd = '/usr/bin/php';
    args = ['-f', 'php/handlers/project.php', '--'];
    channel = msg.message.room;
    args.push channel;
    user = msg.message.user.id;
    args.push user;
    subcommand = msg.match[1];
    args.push subcommand;
    run_cmd cmd, args, (text) -> msg.send text;
