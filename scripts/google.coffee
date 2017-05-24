# Description:
#   Returns the URL of the first google hit for a query
# 
# Dependencies:
#   None
#
# Configuration:
#   None
#

module.exports = (robot) ->
  robot.respond /(google)( me)? (.*)/i, (msg) ->
    googleMe msg, msg.match[3], (url) ->
      msg.send url

googleMe = (msg, query, cb) ->
  msg.http('http://www.google.nl/search')
    .query(q: query)
    .get() (err, res, body) ->
      cb body.match(/class="r"><a href="\/url\?q=([^"]*)(&amp;sa.*)">/)?[1] || "Sorry, Google had zero results for '#{query}'"
