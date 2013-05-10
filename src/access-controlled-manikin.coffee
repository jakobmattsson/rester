_ = require 'underscore'
async = require 'async'
manikinTools = require 'manikin-tools'



class AuthError extends Error
  constructor: (msg) -> @message = msg

class ClientError extends Error
  constructor: (msg) -> @message = msg



joinFilters = (filter1, filter2) ->
  return if !filter1? || !filter2?
  dupKeys = _.intersection(Object.keys(filter1), Object.keys(filter2))
  return if dupKeys.some (name) -> filter1[name]?.toString() != filter2[name]?.toString()
  _.extend({}, filter1, filter2)


propagate = (onErr, onSucc) ->
  (err, rest...) ->
    return onErr(err) if err?
    return onSucc(rest...)


exports.AuthError = AuthError
exports.ClientError = ClientError
exports.build = (db, mods, authinfo) ->

  metaData = manikinTools.getMeta(mods)

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
    authorizationFilter model, {}, 'create', propagate callback, (finalFilter) =>
      db.post.call(this, model, indata, callback)

  newdb.list = (model, filter, callback) ->
    authorizationFilter model, filter, 'read', propagate callback, (finalFilter) =>
      db.list.call(this, model, finalFilter, callback)

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
    secondaryModel = getSecondaryModelInManyToMany(primaryModel, propertyName)

    async.map [
      { model: primaryModel, filter: { id: primaryId } }
      { model: secondaryModel, filter: filter }
    ], (item, callback) ->
      authorizationFilter(item.model, item.filter, 'read', callback)
    , propagate callback, (finalFilters) =>
      db.getOne.call this, primaryModel, { filter: finalFilters[0] }, propagate callback, ->
        db.getMany(primaryModel, primaryId, propertyName, finalFilters[1], callback)

  ['delMany', 'postMany'].forEach (manyMethod) ->

    newdb[manyMethod] = (primaryModel, primaryId, propertyName, secondaryId, callback) ->
      secondaryModel = getSecondaryModelInManyToMany(primaryModel, propertyName)

      async.map [
        { model: primaryModel, filter: { id: primaryId } }
        { model: secondaryModel, filter: { id: secondaryId } }
      ], (item, callback) =>
        authorizationFilter item.model, item.filter, 'write', propagate callback, (ff) =>
          db.getOne.call(this, item.model, { filter: ff }, callback)
      , propagate callback, ->
        db[manyMethod](primaryModel, primaryId, propertyName, secondaryId, callback)

  newdb
