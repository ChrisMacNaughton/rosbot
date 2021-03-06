# Description:
#   Allows Hubot to send text messages using 46elks.com API.
#
# Dependencies:
#   None
#
# Configuration:
#   SMS_USERNAME
#   SMS_PASSWORD
#
#
# Author:
#   kimf

QS      = require "querystring"
module.exports = (robot) ->

  getAmbiguousUserText = (users) ->
    "Be more specific, I know #{users.length} people named like that: #{(user.name for user in users).join(", ")}"

  robot.respond /sms (\w+) (.*)/i, (msg) ->
    to    = msg.match[1]
    bahdy = msg.match[2] # bahdy, that's how john mayer would say it.
    user  = process.env.SMS_USERNAME
    pass  = process.env.SMS_PASSWORD
    from  = "Rosbot"
    auth  = 'Basic ' + new Buffer(user + ':' + pass).toString("base64")
    
    unless user
      msg.send "46Elks USERNAME isn't set."
      msg.send "Please set the SMS_USERNAME environment variable."
      return

    unless pass
      msg.send "46Elks PASSWORD isn't set."
      msg.send "Please set the SMS_PASSWORD environment variable."
      return

    #get <user>'s phone number as listed in the brain
    if user = robot.brain.userForName(to)
      if user.phone == ""
        msg.send user.name + ' has no phone! set it with <user> has phone <phone>'
        return
      else
        to = user.phone
    else 
      users = robot.brain.usersForFuzzyName(to)
      if users.length is 1
        user = users[0]
        to = user.phone
      else if users.length > 1
        msg.send getAmbiguousUserText users
        return
      else
        msg.send 'Me cant find ' + to + ', are you sure that person is born?'
        return    

    data  = QS.stringify from: from, to: to, message: bahdy

    msg.http("https://api.46elks.com")
      .path("/a1/SMS")
      .header("Authorization", auth)
      .post(data) (err, res, body) ->
        switch res.statusCode
          when 200
            msg.send "Sent sms to #{user.name}"
          else
            msg.send "Failed to send."

  robot.respond /@?([\w .-_]+) has phone number (\d*)*$/i, (msg) ->
    name  = msg.match[1]
    phone = msg.match[2]
    console.log name
    console.log phone
  
    users = robot.brain.usersForFuzzyName(name)
    console.log users
    if users.length is 1
      user = users[0]
      if user.phone == phone
        msg.send "I know."
      else
        user.phone = phone
        msg.send "Ok, #{name} has phone #{phone}."
    else if users.length > 1
      msg.send getAmbiguousUserText users
    else
      msg.send "I don't know anything about #{name}."



  robot.respond /@?give me the phone number to ([\w .-_]+)*/i, (msg) ->
    name  = msg.match[1]
    users = robot.brain.usersForFuzzyName(name)
    if users.length is 1
      user = users[0]
      if user.phone.length < 1
        msg.send "#{user.name} has no phone, set it first!"
      else
        msg.send "#{user.name} has phone number #{user.phone}."        
    else if users.length > 1
      msg.send getAmbiguousUserText users
    else
      msg.send "I don't know anything about #{name}."
