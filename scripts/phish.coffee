# Description:
#   phishhing report from hubot
#
# Dependencies:
#
# Configuration:
#   None
#
# Author:
#   John Sinteur
#

url = require 'url'
querystring = require 'querystring'

module.exports = (robot) ->
  gitlabChannel = "oSZ25EnJXgWaqJfw3"

  trim_commit_url = (url) ->
    url.replace(/(\/[0-9a-f]{9})[0-9a-f]+$/, '$1')

  robot.router.post '/hubot/chatsecrets/:room', (req, res) ->
     robot.messageRoom gitlabChannel, "@ I received a click in  phishing email by: #{req.params.room}"
     res.send 'OK'

  robot.router.post '/hubot/imageviews/:room', (req, res) ->
     robot.messageRoom gitlabChannel, "@ I received an imageview in  phishing email by: #{req.params.room}"
     res.send 'OK'

