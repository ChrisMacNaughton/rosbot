# Description:
#   Returns the URL of the first google hit for a query
# 
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   google me <query> - Googles <query> & returns 1st result's URL
#
# Author:
#   searls

module.exports = (robot) ->
  robot.respond /(lmbtfy)( me)? (.*)/i, (msg) ->
    msg.send "http://lmbtfy.com/?q=" + msg.match[3]
  robot.respond /(lmgtfy)( me)? (.*)/i, (msg) ->
    msg.send "http://lmgtfy.com/?q=" + msg.match[3]

