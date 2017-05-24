# Description:
#   Example scripts for you to examine and try out.
#
# Notes:
#   They are commented out by default, because most of them are pretty silly and
#   wouldn't be useful and amusing enough for day to day huboting.
#   Uncomment the ones you want to try and experiment with.
#
#   These are from the scripting documentation: https://github.com/github/hubot/blob/master/docs/scripting.md
# Commands:
#   make me a channel CHANNELNAME - create a chat channel (limited to authorized users)
#   startofferte OFFERTENAME - create a channel, repo, kanboard for an offerte (limited to authorized users)
#   startpentest PENTESTNAME - create a channel, repo, kanboard for a pentest (limited to authorized users)
#   kanboard BOARDNAME - shows kanboard status
#   make an issue DESCRIPTIVE TEXT - creates a git issue related to the current channel
#   cvesearch PRODUCT - searches CVE database for a product
#   archive the chat log for CHANNELNAME - creates a text dump of all the chat in CHANNELNAME in the git repo with the same name (limited to authorized users)
#   rainbowtables algorithm hash - tries to find the hash in the available rainbowtables
#   shellcmd  grabimage url - turns a web page into a picture
#   availability  (date expression) - shows who is available and what they're doing
#   kanboardcomment DESCRIPTIVE TEXT - add a comment to the kanboard item related to the current channel
#   kanboardinfo COUNT - show the last COUNT comments from the kanboard item related to the current channel
#   shellcmd buildwebsite  - pull the most recent website version from github and install it
#   charge 1.0  - register a number of hours (decimal point if you do fractions please) for this channel
#   chargelist  - show all charges registered to this channel


Q = require 'q'
path = require('path')
fs = require("fs")


aclFileName = "acl.yml"
aclModule = require "./rosutils"

_ = require('lodash')


process.env.HUBOT_PHPCMD = "php/handler" if not process.env.HUBOT_PHPCMD
if not fs.existsSync(process.env.HUBOT_PHPCMD)
  console.log process.env.HUBOT_PHPCMD+" not found in hubot working dir..defaulting to example handler at "+__dirname+"/../php/handler"
  process.env.HUBOT_PHPCMD = __dirname+"/../php/handler" 
process.env.HUBOT_PHPCMD_KEYWORD = "php" if not process.env.HUBOT_PHPCMD_KEYWORD

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




module.exports = (robot) ->
  robot.router.post '/hubot/githook/:room', (req, res) ->
    room   = req.params.room
    data   = if req.body.payload? then JSON.parse req.body.payload else req.body
    robot.messageRoom room, "I just received a message from gitlabs: "
    robot.messageRoom room, data.secret
    res.send 'OK'

  robot.router.post '/hubot/webhook/:room', (req, res) ->
    room   = req.params.room
    data   = if req.body.payload? then JSON.parse req.body.payload else req.body
    robot.messageRoom room, "I just received a message from a web callback: "
    robot.messageRoom room, data.secret
    res.send 'OK'



  robot.respond /you are a little slow/, (res) ->
   setTimeout () ->
     res.send "Who you calling 'slow'?"
   , 60 * 1000

  robot.respond /make me a channel (.*)/i,  id:'chatops.channelcreation', (res) ->
    roomName = res.match[1]

    userValidated = aclModule.validate( aclFileName, res.envelope.user.name, 'aclForMakeMeAChannel' )

    if !userValidated
      res.send "I am sorry " + res.envelope.user.name + " but I have not been told you are allowed to ask for that"
      return;

    res.send "Sure, hold on"
    newroom = robot.adapter.callMethod('createPrivateGroup', roomName, ['johnsinteur', 'melanie'])
    res.send  "+done - Added John, Melanie to the new room"
    newroom.then (roomId) =>
      robot.messageRoom roomId.rid, "@all hello!"


  # robot.hear /badger/i, (res) ->
  #   res.send "Badgers? BADGERS? WE DON'T NEED NO STINKIN BADGERS"
  #
  # robot.respond /open the (.*) doors/i, (res) ->
  #   doorType = res.match[1]
  #   if doorType is "pod bay"
  #     res.reply "I'm afraid I can't let you do that."
  #   else
  #     res.reply "Opening #{doorType} doors"
  #
  # robot.hear /I like pie/i, (res) ->
  #   res.emote "makes a freshly baked pie"
  #
  # lulz = ['lol', 'rofl', 'lmao']
  #
  # robot.respond /lulz/i, (res) ->
  #   res.send res.random lulz
  #
  # robot.topic (res) ->
  #   res.send "#{res.message.text}? That's a Paddlin'"
  #
  #
  # enterReplies = ['Hi', 'Target Acquired', 'Firing', 'Hello friend.', 'Gotcha', 'I see you']
  # leaveReplies = ['Are you still there?', 'Target lost', 'Searching']
  #
  # robot.enter (res) ->
  #   res.send res.random enterReplies
  # robot.leave (res) ->
  #   res.send res.random leaveReplies
  #
  # answer = process.env.HUBOT_ANSWER_TO_THE_ULTIMATE_QUESTION_OF_LIFE_THE_UNIVERSE_AND_EVERYTHING
  #
  # robot.respond /what is the answer to the ultimate question of life/, (res) ->
  #   unless answer?
  #     res.send "Missing HUBOT_ANSWER_TO_THE_ULTIMATE_QUESTION_OF_LIFE_THE_UNIVERSE_AND_EVERYTHING in environment: please set and try again"
  #     return
  #   res.send "#{answer}, but what is the question?"
  #
  #
  # annoyIntervalId = null
  #
  # robot.respond /annoy me/, (res) ->
  #   if annoyIntervalId
  #     res.send "AAAAAAAAAAAEEEEEEEEEEEEEEEEEEEEEEEEIIIIIIIIHHHHHHHHHH"
  #     return
  #
  #   res.send "Hey, want to hear the most annoying sound in the world?"
  #   annoyIntervalId = setInterval () ->
  #     res.send "AAAAAAAAAAAEEEEEEEEEEEEEEEEEEEEEEEEIIIIIIIIHHHHHHHHHH"
  #   , 1000
  #
  # robot.respond /unannoy me/, (res) ->
  #   if annoyIntervalId
  #     res.send "GUYS, GUYS, GUYS!"
  #     clearInterval(annoyIntervalId)
  #     annoyIntervalId = null
  #   else
  #     res.send "Not annoying you right now, am I?"
  #
  #
  #
  # robot.error (err, res) ->
  #   robot.logger.error "DOES NOT COMPUTE"
  #
  #   if res?
  #     res.reply "DOES NOT COMPUTE"
  #
  # robot.respond /have a soda/i, (res) ->
  #   # Get number of sodas had (coerced to a number).
  #   sodasHad = robot.brain.get('totalSodas') * 1 or 0
  #
  #   if sodasHad > 4
  #     res.reply "I'm too fizzy.."
  #
  #   else
  #     res.reply 'Sure!'
  #
  #     robot.brain.set 'totalSodas', sodasHad+1
  #
  # robot.respond /sleep it off/i, (res) ->
  #   robot.brain.set 'totalSodas', 0
  #   res.reply 'zzzzz'

  run_cmd = (cmd, args, cb ) ->
    console.log "spawn!"
    spawn = require("child_process").spawn
    child = spawn(cmd, args)
    child.stdout.on "data", (buffer) -> cb buffer.toString()
    child.stderr.on "data", (buffer) -> cb buffer.toString()
    #child.stdout.on "end", -> cb resp


  robot.respond "/"+process.env.HUBOT_PHPCMD_KEYWORD+" (.*)/i", (msg) ->
    msg.match[0] = msg.match[0].replace(/^[a-z0-9]+$/i);
    msg.match.shift();

    userValidated = aclModule.validate( aclFileName, msg.envelope.user.name, 'aclForPhpCmd' )

    if !userValidated
      msg.send "I am sorry " + msg.envelope.user.name + " but I have not been told you are allowed to ask for that"
      return;

    args = msg.match[0].split(" ");
    cmd = process.env.HUBOT_PHPCMD;
    run_cmd cmd, args, (text) -> msg.send text.replace("\n","")

  robot.hear /EHLO/i, (res) ->
   res.send "250-rosbot listening, " + res.envelope.user.name
   res.send "250-PIPELINING"
   res.send "250-SIZE 302400000"
   res.send "250 DSN"


  robot.respond /startofferte (.*)/i, id:'chatops.startofferte',(msg) ->
# Usage: startofferte {clientname-projectname}. Creates a chat channel, git repo, and kanboard item and prefills it with a basic set of information to get the quote process started
    msg.match[0] = msg.match[0].replace(/^[a-z0-9]+$/i);
    msg.match.shift();
    args = msg.match[0].split(" ");
    if args[0].substring(0, 4) == "pen-"
      msg.send "[-] Please do not start offerte names with pen-";
      return;
    if args[0].substring(0, 4) == "off-"
      msg.send "[-] Please do not start offerte names with off-";
      return;
    msg.send "[+] ok, hold, setting up offerte " + args[0];
    projectName = args[0];
    cmd = '/usr/bin/php';
    args = ['-f', 'php/handlers/startofferte.php', '--'];
    args.push projectName;
    run_cmd cmd, args, (text) -> msg.send text;

  robot.respond /johntest (.*)/i, (msg) ->
    for key, val of robot.brain
      console.log key + ': ' + val 
    for key, val of robot.adapter
      console.log key + ': ' + val 


#  robot.hear /@all/i, (msg) ->
#    msg.send  "o.O"


  robot.respond /kanboard (.*)/i, (msg) ->
    msg.match[0] = msg.match[0].replace(/^[a-z0-9]+$/i);
    msg.match.shift();
    args = msg.match[0].split(" ");
    msg.send "[+] ok, hold, getting status for " + args[0];
    boardName = args[0];
    cmd = "php/handler_kanboardstatus";
    run_cmd cmd, args, (text) -> msg.send text.replace("\n","");

  robot.respond /kanboardcomment (.*)/i, (msg) ->
    cmd = "php/handler_kamboardcomment";
    args = [msg.message.room, msg.match[0] ]
    run_cmd cmd, args, (text) -> msg.send text.replace("\n","");

  robot.respond /kanboardinfo (.*)/i, (msg) ->
    cmd = "php/handler_kanboardinfo";
    args = [msg.message.room, msg.match[0] ]
    run_cmd cmd, args, (text) -> msg.send text.replace("\n","");


  robot.respond /charge (.*)/i, (msg) ->
    cmd = "php/handler_charge"
    chatdrv = robot.adapter.chatdriver
    roomName = ""

    localcmd = chatdrv.callMethod( 'canAccessRoom' , [ msg.envelope.user.room, msg.envelope.user.id] ) 
    permit_cmd = false
  
    Q(localcmd)
    .then( ( room_data ) =>
      roomName = room_data.name ; 

      params = _.split( _.trim( msg.match[1] ) , /\s+/ )
      response_msg = if params.length < 2 then 'Enter exactly hour and description' else ''

      desc = _.join( _.slice( params, 1) , ' ')
      
      if response_msg != ''
        msg.reply( response_msg )
        return

      pre_hours = _.toNumber( params[0] );
  
      hours = if _.isNumber( pre_hours ) and pre_hours > 0 then pre_hours  else false

      response_msg = if !hours then 'Enter valid hour' else ''

      #if response_msg != '' then msg.reply( response_msg )
      if response_msg != ''
        msg.reply( response_msg )
        return

      #args = [msg.message.room, msg.envelope.user.name, msg.match[0] , msg.match[1] ]
      args = [ roomName , msg.envelope.user.name, hours, desc ]
  
      if response_msg == ''
        run_cmd cmd, args, (text) -> msg.send text.replace("\n","");

      roomName

    )
    .catch((err) =>
      @robot.logger.error "Unable to : extract Room Titiel #{JSON.stringify(err)} Reason: #{err.reason}"
    )


  robot.respond /chargehere (.*)/i, (msg) ->
    cmd = "php/handler_chargehere";
    args = [msg.message.room, msg.envelope.user.name, msg.match[0] , msg.match[1] ]
    run_cmd cmd, args, (text) -> msg.send text.replace("\n","");
#    imageMe msg, "cha-ching", true, (url) ->
#      msg.send url

  robot.respond /chargelist/i, (msg) ->
    userValidated = aclModule.validate( aclFileName, msg.envelope.user.name, 'aclForChargeList' )

    if !userValidated
      msg.send "I am sorry " + msg.envelope.user.name + " but I have not been told you are allowed to ask for that"
      return;

    cmd = "php/handler_chargelist";
    args = [msg.message.room ]
    run_cmd cmd, args, (text) -> msg.send text;




# msg.envelope.room - id


  robot.router.post '/kanboardtaskcallback', (req, res) ->
     console.log req.body
     console.log req.body.room

     robot.messageRoom req.body.room , req.body.message
     robot.messageRoom req.body.room , req.body.url
     res.send 'OK'

  robot.respond /make an issue (.*)/i, (msg) ->
    cmd = "php/handler_issue";
    args = [msg.message.room, msg.match[0] ]
    run_cmd cmd, args, (text) -> msg.send text.replace("\n","");

  robot.respond /cvesearch (.*)/i, (msg) ->
    cmd = "php/handler_cve";
    args = [ '"' + msg.match[0] + '"' ]
    run_cmd cmd, args, (text) -> msg.send text.replace("\n","");


  robot.respond /cve (.*)/i, (msg) ->
    cmd = "php/handler_cve2";
    args = [ '"' + msg.match[0] + '"' ]
    run_cmd cmd, args, (text) -> msg.send text.replace("\n","");

  robot.respond /rainbowtables (.*)/i, (msg) ->
    cmd = "/opt/rosbot/rainbow/rainbowtables";
    argsstr = msg.match[1] ;
    args = argsstr.split " ";
    run_cmd cmd, args, (text) -> msg.send text;
    #.replace("\n","");


  robot.respond /passwordstatus/i, (msg) ->
    spawn = require("child_process").spawn
    child = spawn '/home/sinteur/john-1.8.0/run/john', ['--status']
    child.stdout.on "data", (buffer) -> msg.send buffer.toString()
    child.stderr.on "data", (buffer) -> msg.send buffer.toString()

  robot.respond /passwordshow/i, (msg) ->
    args = msg.match[0].split(" ");
    run_cmd '/home/sinteur/john-1.8.0/run/john', args, (text) -> msg.send text.replace("\n","");

  robot.router.post '/hubot/automessage/:room', (req, res) ->
     room   = req.params.room
     console.log req.body
     data   = if req.body.payload? then JSON.parse req.body.payload else req.body
     console.log data
     robot.messageRoom room, data.msg
  
     res.send 'OK'

  robot.router.post '/hubot/automessagedirect/:user', (req, res) ->
     user   = req.params.user
#     console.log robot.adapter.chatdriver
     data   = if req.body.payload? then JSON.parse req.body.payload else req.body
     channel = robot.adapter.chatdriver.getDirectMessageRoomId(user)
     channel = robot.adapter.chatdriver.getDirectMessageRoomId(user)
     Q(channel)
     .then((chan) =>
          robot.messageRoom chan.rid, data.msg
     )
     .catch((err) =>
         console.log "Unable to get DirectMessage Room ID: #{JSON.stringify(err)} Reason: #{err.reason}"
     )
     res.send 'OK'



  robot.respond /kanboardstatus/i, (msg) ->
    msg.http("http://localhost/getkbtasklist2.php")
      .get() (err, res, body) ->
        if res.statusCode == 404
          msg.send 'Not found.'
        else
          msg.send 'Done'




  robot.respond /archive the chat log for (.*)/i, id:'chatops.chatlog', (msg) ->
    roomName = msg.match[1];
    cmd = '/usr/bin/php';
    args = ['-f', 'php/handlers/roomexport.php', '--'];
    user = msg.message.user.id;
    args.push user;
    args.push roomName;
    run_cmd cmd, args, (text) -> msg.send text;


  robot.respond /regenerate onboarding manual/i, (msg) ->
    userValidated = aclModule.validate( aclFileName, msg.envelope.user.name, 'aclForRegenerateOnboardingManual' )

    if !userValidated
      msg.send "[-] I am sorry " + msg.envelope.user.name + " but I have not been told you are allowed to do that";
      return;

    cmd = "bash/handler_onboardingmanual";
    run_cmd cmd, [ ], (text) -> msg.send text.replace("\n","");


  robot.respond /availability (.*)/i,  (msg) ->
    userValidated = aclModule.validate( aclFileName, msg.envelope.user.name, 'aclForAvailability' )

    if !userValidated
      msg.send "[-] I am sorry " + msg.envelope.user.name + " but I have not been told you are allowed to ask for that";
      return;

    args = msg.match[0].split(" ");
    cmd = "php/handler_avail";
    run_cmd cmd, [ args ], (text) -> msg.send text.replace("\n","");








  robot.respond /testAI (.*)/i, (msg) ->
    console.log msg.match[1]
    msg.http("http://localhost:8081/gui/empty/index.php?format=json&say=" + msg.match[1])
      .get() (err, res, body) ->
        if res.statusCode == 404
          msg.send 'AI not found.'
        else
          object = JSON.parse(body)
          msg.send object.botsay
