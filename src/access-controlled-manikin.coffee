_ = require 'underscore'
async = require 'async'
manikinTools = require 'manikin-tools'



propagate = (onErr, onSucc) ->
  (err, rest...) ->
    return onErr(err) if err?
    return onSucc(rest...)



exports.AuthError = class AuthError extends Error
  constructor: (msg) -> @message = msg



exports.ClientError = class ClientError extends Error
  constructor: (msg) -> @message = msg



exports.joinFilters = joinFilters = (args...) ->
  cured = args.map (x) -> x || {}
  return {} if args.length == 0
  cured.slice(1).reduce (memo, arg) ->
    return if !memo?
    dupKeys = _.intersection(Object.keys(memo), Object.keys(arg))
    return if dupKeys.some (name) -> memo[name].toString() != arg[name].toString()
    _.extend({}, memo, arg)
  , cured[0]



exports.build = (db, mods, authinfo) ->

  metaData = manikinTools.getMeta(manikinTools.desugar(mods))

  getAuthorizationFunc = (model, func) ->
    funcs = {
      read: mods[model].auth || -> {}
      write: mods[model].authWrite
      create: mods[model].authCreate
    }
    funcs.write ?= funcs.read
    funcs.create ?= funcs.write
    funcs[func]

  authorizationFilter = (model, filter, level, callback) ->
    authfilter = getAuthorizationFunc(model, level)
    x = authfilter(authinfo)
    if !x
      callback(new AuthError('unauthed'))
      return

    finalFilter = joinFilters(filter, x)
    if !finalFilter?
      callback(new AuthError('unauthed'))
      return

    callback(null, finalFilter)

  getSecondaryModelInManyToMany = (primaryModel, propertyName) ->
    metaData[primaryModel].manyToMany.filter((x) -> x.name == propertyName)[0].ref



  newdb = {}
  newdb.connect = db.connect
  newdb.close = db.close

  newdb.post = (model, indata, callback) ->
    authorizationFilter model, indata, 'create', propagate callback, (finalData) =>
      db.post.call(this, model, finalData, callback)

  newdb.list = (model, config, callback) ->
    authorizationFilter model, (config.filter || {}), 'read', propagate callback, (finalFilter) =>
      db.list.call(this, model, _.extend({}, config, { filter: finalFilter }), callback)

  newdb.getOne = (model, config, callback) ->
    authorizationFilter model, config.filter || {}, 'read', propagate callback, (finalFilter) =>
      db.getOne.call(this, model, _.extend({}, config, { filter: finalFilter }), callback)

  newdb.delOne = (model, filter, callback) ->
    authorizationFilter model, filter, 'write', propagate callback, (finalFilter) =>
      db.delOne.call(this, model, finalFilter, callback)

  newdb.putOne = (model, data, filter, callback) ->
    authorizationFilter model, filter, 'write', propagate callback, (finalFilter) =>
      db.putOne.call(this, model, data, finalFilter, callback)

  newdb.getMany = (primaryModel, primaryId, propertyName, filter, callback) ->
    async.map [
      { model: primaryModel, filter: { id: primaryId } }
      { model: getSecondaryModelInManyToMany(primaryModel, propertyName), filter: filter }
    ], (item, callback) ->
      authorizationFilter(item.model, item.filter, 'read', callback)
    , propagate callback, (finalFilters) =>
      db.getOne.call this, primaryModel, { filter: finalFilters[0] }, propagate callback, ->
        db.getMany(primaryModel, primaryId, propertyName, finalFilters[1], callback)

  ['delMany', 'postMany'].forEach (manyMethod) ->
    newdb[manyMethod] = (primaryModel, primaryId, propertyName, secondaryId, callback) ->
      async.map [
        { model: primaryModel, filter: { id: primaryId } }
        { model: getSecondaryModelInManyToMany(primaryModel, propertyName), filter: { id: secondaryId } }
      ], (item, callback) =>
        authorizationFilter item.model, item.filter, 'write', propagate callback, (ff) =>
          db.getOne.call(this, item.model, { filter: ff }, callback)
      , propagate callback, ->
        db[manyMethod](primaryModel, primaryId, propertyName, secondaryId, callback)

  newdb
