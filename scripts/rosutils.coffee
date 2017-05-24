fs = require('fs')
yaml = require('js-yaml')
fs = require('fs')
path = require('path')
_ = require('lodash')


class AclValidator
  constructor: ( aclFileName ) ->
    @file = aclFileName
    @aclFileData = null


  loadFile: () -> 
    try
      yaml.safeLoad(fs.readFileSync( @file , 'utf8'));

    catch ex
      throw "Exception: " + ex

    
  getUsers : ( content, cmdName ) ->
    handler = _.filter( content.handlers, "name": cmdName )

    if handler.length > 0
      handler[0].acl.users
    else 
      []


  checkFileAccess : () ->
    fs.stat @file, ( err, stats ) =>
      @parseFileStat( stats )


  parseFileStat : ( octalFileStats ) ->
    decimalFileStats =  '0' + (octalFileStats.mode & parseInt('777', 8)).toString(8);

    if parseInt(decimalFileStats[3]) > 0
      throw "Invalid acl file permissions : #{decimalFileStats}"


validateRosUser = ( aclFileName, user, cmd ) ->
  try
    av = new AclValidator path.join( __dirname , aclFileName )

    content = av.loadFile()
    aclUsers = av.getUsers( content, cmd )

    user in aclUsers

  catch ex
    console.log "Exception in validateRosUser: " + ex

module.exports = { aclValidator: AclValidator, validate: validateRosUser }
