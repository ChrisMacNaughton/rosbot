# Description:
#   Manual scripting
#
# Notes:
#   Custom documentation parsing
#   manual.yml - YAML entry file for documentation
#   These are from the scripting documentation: https://github.com/github/hubot/blob/master/docs/scripting.md
# Commands:
#   man  - show manual sections
#   man section _NAME_ - show manual sections
#   man CMD  - show usage for CMD
#   man CMD detail - show CMD usage detail (id CMD have detail option)

Q = require 'q'
fs = require("fs")
yaml = require('js-yaml')

_ = require('lodash')

manData = yaml.safeLoad(fs.readFileSync( __dirname + '/manual.yml', 'utf8'));

module.exports = (robot) ->
  robot.respond /help/i, (msg) ->
    robot_name = "@" + ( robot.alias or robot.name ) + " "
    feedback = robot_name + "ROS related help, type : " +  robot_name + " man"
    msg.sendDirect feedback
    

  robot.respond /man (\w+\s+)+detail$/i, (msg) ->
    robot_name = "@" + ( robot.alias or robot.name ) + " "

    splitted = _.split(msg.match.input.trim(), /\s+/)

    # current_cmd = _.toLower( splitted.slice( 2, splitted.length-1 ).join(' ') )
    current_cmd = splitted.slice( 2, splitted.length-1 ).join(' ')

    res = _.filter( manData.manuals, { "name" : current_cmd } )
    item = res[0]

    if _.isUndefined( item )
      feedback = "Command \"" + current_cmd + "\" does not exist"
    else if _.isArray( item.detail )
      feedback = robot_name + "man " + current_cmd + "\n" + item.detail.join('\n')
    else if _.isString( item.detail )
      feedback = robot_name + "man " + current_cmd + " detail : \n\n" + item.detail
    else if _.isUndefined( item.detail )
      feedback = "No detail for command \"" + current_cmd + "\""

    msg.sendDirect feedback
    

  robot.respond /man\s+section\s+\w+\s*$/i, (msg) ->
    robot_name = "@" + ( robot.alias or robot.name ) + " "

    splitted = _.split(msg.match.input.trim(), /\s+/)
    sectionName = splitted[3]

    head = "\nROS commands :\n\n"
    tail = "\n\nfor command description type \"man cmd\" "

    permitted_data = _.filter manData.manuals, (value, key) -> ( value.section.name == sectionName ) && ( !(_.has( value , "hidden") || value.hidden is false ) )

    pretext = robot_name + "man "

    # res = _.map( permitted_data, "name" ).join( '\t\n')
    # parsed_data = permitted_data.map( (x) => pretext + x.name + posttext + x.desc )

    parsed_data = permitted_data.map( (x) => pretext + x.name )

    feedback = if parsed_data.length == 0 then "Section name does not found" else parsed_data.join("\n")
    msg.sendDirect feedback


  robot.respond /man\s+\w+(\s+\w+)*$/i, (msg) ->
    robot_name = "@" + ( robot.alias or robot.name ) + " "

    splitted = _.split(msg.match.input.trim(), /\s+/)

    if _.last( splitted ) is 'detail' || splitted[2]=='section'
      return

    current_cmd = splitted.slice( 2, splitted.length ).join(' ')

    res = _.filter( manData.manuals, { "name" : current_cmd } )
    item = res[0]

    detail_info = if _.has( item, 'detail') then "\nfor command details type : " + robot_name + "man " + current_cmd + " detail" else ""

    if _.isUndefined( item )
      description = ""
    else if _.isArray( item.desc )
      description = item.desc.join('\n')
    else if _.isString( item.desc )
      description = item.desc

    feedback = if res.length != 0 then robot_name + current_cmd + " " + description + detail_info else "No description for command \"" + current_cmd + "\""

    msg.sendDirect feedback


  robot.respond /man\s*$/, (msg) ->
    robot_name = "@" + ( robot.alias or robot.name ) + " "
    sectionNames = manData.sections

    pretext = robot_name + "man section "
    posttext = " - "

    feedback = sectionNames.map( (x) => pretext + x.name + posttext + x.desc )
    msg.sendDirect feedback.join("\n")
