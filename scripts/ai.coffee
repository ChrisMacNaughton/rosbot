# Description:
#   ALICE for hubot
#
# Commands:
#   hubot discuss (with me) - Creates a new conversation 
#   hubot talk (with/to me) - Creates a new conversation 
#   hubot discuss cancel - Cancels the conversation 
#   hubot sst - Cancels the conversation 
#   hubot discuss goodbye - Cancels the conversation 
#
# Author:
#   John Sinteur
#


class Discussion
    constructor: (@callback) ->
        @pending = []
        @discussion_id

    addPending: (user, message) ->
        reminder = @getPending user
        return [false, reminder] if reminder isnt false
        payload = [user, message]
        @pending.push payload
        [true, payload]

    cancelPending: (user) ->
        if reminder = @getPending user
            @pending.splice @pending.indexOf(reminder), 1
            return true
        false

    getPending: (user) ->
        for reminder, index in @pending
            return reminder if reminder[0].id is user.id
        false

    complete: (user, executionDate) ->
        if reminder = @getPending user
            @pending.splice @pending.indexOf(reminder), 1
            return [reminder[0], reminder[1], executionDate]
        false



module.exports = (robot) ->
    BrainDiscussions = ->
        robot.brain.data['ROSBOTDISCUSSIONS'] or= []

    Discussion = new Discussion (user, message, executionDate) ->
        message = "Discussion for @#{user.name}: #{message}"
        #robot.send {room: user.room, user: user}, message
        old = [user, message, executionDate]
        BrainDiscussions().splice BrainDiscussions().indexOf old, 1

    robot.respond /discus(sion) cancel/i, id: "remind.cancel", (res) ->
        if Discussion.cancelPending res.message.user
            res.reply "Goodbye."
        else
            res.reply "Were we talking?"
        res.finish()

    robot.respond /sst/i, id: "remind.cancel", (res) ->
        if Discussion.cancelPending res.message.user
            res.reply "Goodbye."
        else
            res.reply "Were we talking?"
        res.finish()


    robot.respond /discuss( with)( me)? (.+)/i, id: "remind.new", (res) ->
        [status, reminder] = Discussion.addPending res.message.user, res.match[2]
        res.reply "Hello, what can I do for you today?"
        res.finish()

    robot.respond /talk( with)( to)( me)? (.+)/i, id: "remind.new", (res) ->
        [status, reminder] = Discussion.addPending res.message.user, res.match[2]
        res.reply "Hello, what can I do for you today?"
        res.finish()

    robot.hear /(.+)/i, id: "discussion.process", (res) ->
        return unless Discussion.pending.length isnt 0
        
        res.http("http://localhost:8081/gui/empty/index.php?format=json&convo_id=" + Discussion.discussion_id + "&say=" + res.match[1])
          .get() (err, res2, body) ->
            if res2.statusCode == 404
              res.send 'AI not found.'
            else
              object = JSON.parse(body)
              res.send object.botsay
              Discussion.discussion_id = object.convo_id
            robot.brain.save()

    robot.brain.on "loaded", ->
        robot.logger.info "hubot-AI-advanced: Loading discussions from brain."

