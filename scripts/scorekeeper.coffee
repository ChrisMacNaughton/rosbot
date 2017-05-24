# Description:
#   Let hubot track your co-workers' honor points
#
# Configuration:
#   HUBOT_SCOREKEEPER_MENTION_PREFIX
#
# Commands:
#   <name>++ - Increment <name>'s point
#   <name>-- - Decrement <name>'s point
#   scorekeeper - Show scoreboard
#   show scoreboard - Show scoreboard
#   scorekeeper <name> - Show current point of <name>
#   what's the score of <name> - Show current point of <name>
#
# Author:
#   yoshiori

path = require('path')
fs = require("fs")

aclFileName = "acl.yml"
aclModule = require "./rosutils"

imageMe = (msg, query, animated, faces, cb) ->
  cb = animated if typeof animated == 'function'
  cb = faces if typeof faces == 'function'
  googleCseId = process.env.HUBOT_GOOGLE_CSE_ID
  if googleCseId
    # Using Google Custom Search API
    googleApiKey = process.env.HUBOT_GOOGLE_CSE_KEY
    if !googleApiKey
      msg.robot.logger.error "Missing environment variable HUBOT_GOOGLE_CSE_KEY"
      msg.send "Missing server environment variable HUBOT_GOOGLE_CSE_KEY."
      return
    q =
      q: query,
      searchType:'image',
      safe: process.env.HUBOT_GOOGLE_SAFE_SEARCH || 'high',
      fields:'items(link)',
      cx: googleCseId,
      key: googleApiKey
    if animated is true
      q.fileType = 'gif'
      q.hq = 'animated'
      q.tbs = 'itp:animated'
    if faces is true
      q.imgType = 'face'
    url = 'https://www.googleapis.com/customsearch/v1'
    msg.http(url)
      .query(q)
      .get() (err, res, body) ->
        if err
          if res.statusCode is 403
            msg.send "Daily image quota exceeded, using alternate source."
            deprecatedImage(msg, query, animated, faces, cb)
          else
            msg.send "Encountered an error :( #{err}"
          return
        if res.statusCode isnt 200
          msg.send "Bad HTTP response :( #{res.statusCode}"
          return
        response = JSON.parse(body)
        if response?.items
          image = msg.random response.items
          cb ensureResult(image.link, animated)
        else
          msg.send "Oops. I had trouble searching '#{query}'. Try later."
          ((error) ->
            msg.robot.logger.error error.message
            msg.robot.logger
              .error "(see #{error.extendedHelp})" if error.extendedHelp
          ) error for error in response.error.errors if response.error?.errors
  else
    msg.send "Google Image Search API is not longer available. " +
      "Please [setup up Custom Search Engine API](https://github.com/hubot-scripts/hubot-google-images#cse-setup-details)."
    deprecatedImage(msg, query, animated, faces, cb)

deprecatedImage = (msg, query, animated, faces, cb) ->
  # Show a fallback image
  imgUrl = process.env.HUBOT_GOOGLE_IMAGES_FALLBACK ||
    'http://i.imgur.com/CzFTOkI.png'
  imgUrl = imgUrl.replace(/\{q\}/, encodeURIComponent(query))
  cb ensureResult(imgUrl, animated)

# Forces giphy result to use animated version
ensureResult = (url, animated) ->
  if animated is true
    ensureImageExtension url.replace(
      /(giphy\.com\/.*)\/.+_s.gif$/,
      '$1/giphy.gif')
  else
    ensureImageExtension url

# Forces the URL look like an image URL by adding `#.png`
ensureImageExtension = (url) ->
  if /(png|jpe?g|gif)$/i.test(url)
    url
  else
    "#{url}#.png"


class Scorekeeper
  _prefix = "scorekeeper"

  constructor: (@robot) ->
    @_loaded = false
    @_scores = {}
    @robot.brain.on 'loaded', =>
      @_load()
      @_loaded = true

  increment: (user, func) ->
    unless @_loaded
      setTimeout((=> @increment(user,func)), 200)
      return
    @_scores[user] = @_scores[user] or 0
    @_scores[user]++
    @_save()
    @score user, func

  decrement: (user, func) ->
    unless @_loaded
      setTimeout((=> @decrement(user,func)), 200)
      return
    @_scores[user] = @_scores[user] or 0
    @_scores[user]--
    @_save()
    @score user, func

  score: (user, func) ->
    func false, @_scores[user] or 0

  rank: (func)->
    ranking = (for name, score of @_scores
      [name, score]
    ).sort (a, b) -> b[1] - a[1]
    func false, (for i in ranking
      i[0]
    )

  _load: ->
    scores_json = @robot.brain.get _prefix
    scores_json = scores_json or '{}'
    @_scores = JSON.parse scores_json

  _save: ->
    scores_json = JSON.stringify @_scores
    @robot.brain.set _prefix, scores_json


module.exports = (robot) ->
  scorekeeper = new Scorekeeper robot
  mention_prefix = process.env.HUBOT_SCOREKEEPER_MENTION_PREFIX
  if mention_prefix
    mention_matcher = new RegExp("^#{mention_prefix}")

  userName = (user) ->
    user = user.trim().split(/\s/).slice(-1)[0]
    if mention_matcher
      user = user.replace(mention_matcher, "")
    user

  robot.hear /(.+)\+\+$/, (msg) ->
    userValidated = aclModule.validate( aclFileName, res.envelope.user.name, 'aclForScorekeeperPlus' )

    if !userValidated
      res.send "I am sorry " + res.envelope.user.name + " but I have not been told you are allowed to ask for that"
      return;

    user = userName(msg.match[1])
    scorekeeper.increment user, (error, result) ->
      msg.send "incremented #{user} (#{result} pt)"
    imageMe msg, "awesome", true, (url) ->
      msg.send url



  robot.hear /(.+)\-\-$/, (msg) ->
    userValidated = aclModule.validate( aclFileName, res.envelope.user.name, 'aclForScorekeeperMinus' )

    if !userValidated
      res.send "I am sorry " + res.envelope.user.name + " but I have not been told you are allowed to ask for that"
      return;

    user = userName(msg.match[1])
    scorekeeper.decrement user, (error, result) ->
      msg.send "decremented #{user} (#{result} pt)"
    imageMe msg, "Awwwww", true, (url) ->
      msg.send url


    
  robot.respond /scorekeeper$|show(?: me)?(?: the)? (?:scorekeeper|scoreboard)$/i, (msg) ->
    scorekeeper.rank (error, result) ->
      msg.send (for rank, name of result
        "#{parseInt(rank) + 1} : #{name}"
      ).join("\n")

  robot.respond /scorekeeper (.+)$|what(?:'s| is)(?: the)? score of (.+)\??$/i, (msg) ->
    user = userName(msg.match[1] || msg.match[2])
    scorekeeper.score user, (error, result) ->
      msg.send "#{user} has #{result} points"

