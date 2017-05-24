# Description:
#   Rodent Motivation
#
#   Set the environment variable HUBOT_SHIP_EXTRA_SQUIRRELS (to anything)
#   for additional motivation
#
# Dependencies:
#   None
#
# Configuration:
#
# Commands:
#   ship it - Display a motivation squirrel
#
# Author:
#   maddox

module.exports = (robot) ->

  run_cmd = (cmd, args, cb ) ->
    spawn = require("child_process").spawn
    child = spawn(cmd, args)
    child.stdout.on "data", (buffer) -> cb buffer.toString()
    child.stderr.on "data", (buffer) -> cb buffer.toString()

  regex = /ship\s*it(.*)/i

  robot.respond regex, id:'chatops.shipit', (msg) ->
    cmd = '/usr/bin/php';
    args = ['-f', 'php/handlers/shipit.php', '--'];
    channel = msg.message.room;
    args.push channel;
    user = msg.message.user.id;
    args.push user;
    run_cmd cmd, args, (text) -> msg.send text;

  robot.respond /sendinvoice(.*)/i, id:'chatops.sendinvoice', (msg) ->
    cmd = '/usr/bin/php';
    args = ['-f', 'php/handlers/sendinvoice.php', '--'];
    channel = msg.message.room;
    args.push channel;
    args.push msg.match[1];
    run_cmd cmd, args, (text) -> msg.send text;
