_ = require 'underscore'
async = require 'async'
manikinTools = require 'manikin-tools'


class AuthError extends Error
  constructor: (msg) -> @message = msg

class ClientError extends Error
  constructor: (msg) -> @message = msg


exports.AuthError = AuthError
exports.ClientError = ClientError


joinFilters = (filter1, filter2) ->
  return undefined if !filter1? || !filter2?
  dupKeys = _.intersection(Object.keys(filter1), Object.keys(filter2))
  return undefined if dupKeys.some (name) -> filter1[name]?.toString() != filter2[name]?.toString()
  _.extend({}, filter1, filter2)


exports.build = (db, mods, authinfo, config = {}) ->

  originals = db

  newdb = {}
  newdb.connect = db.connect
  newdb.close = db.close

  getModF = (model, func) ->
    funcs = {
      read: mods[model].auth || -> {}
      write: mods[model].authWrite
      create: mods[model].authCreate
    }
    funcs.write ?= authFuncs.read
    funcs.create ?= authFuncs.write
    funcs[func]



  newdb.post = (model, indata, callback) ->
    authfilter = getModF(model, 'create')
    if !authfilter(authinfo)
      callback("some kind of failure")
    else
      originals.post.apply(this, arguments)



  newdb.list = (model, filter, callback) ->
    authfilter = getModF(model, 'read')
    if !authfilter(authinfo)
      callback("some kind of failure")
      return

    finalFilter = joinFilters(filter, authfilter)
    if !finalFilter?
      callback('some other kind of failure')
      return

    originals.list.call(this, model, finalFilter, callback)



  newdb.getOne = (model, config, callback) ->
    authfilter = getModF(model, 'read')
    if !authfilter(authinfo)
      callback("some kind of failure")
      return

    finalFilter = joinFilters(config.filter || {}, authfilter)
    if !finalFilter?
      callback('some other kind of failure')
      return

    originals.getOne.call(this, model, _.extend({}, config, { filter: finalFilter }), callback)



  newdb.delOne = (model, filter, callback) ->
    authfilter = getModF(model, 'write')
    if !authfilter(authinfo)
      callback("some kind of failure")
      return

    finalFilter = joinFilters(filter, authfilter)
    if !finalFilter?
      callback('some other kind of failure')
      return

    originals.delOne.call(this, model, finalFilter, callback)



  newdb.putOne = (model, data, filter, callback) ->
    authfilter = getModF(model, 'write')
    x = authfilter(authinfo)
    if !x
      callback("some kind of failure")
      return

    finalFilter = joinFilters(filter, x)
    if !finalFilter?
      callback('some other kind of failure')
      return

    originals.putOne.call(this, model, data, finalFilter, callback)



  newdb.getMany = original.getMany
  newdb.delMany = original.delMany
  newdb.postMany = original.postMany

  # 
  # # implementera filter-parametern i manikin-core
  # newdb.getMany = (primaryModel, primaryId, propertyName, filter, callback) ->
  # 
  #   secondaryModel = null # figure this out from our metadata, and "primaryModel" and "propertyName"
  # 
  #   async.map [
  #     { model: primaryModel, filter: { id: primaryId } }
  #     { model: secondaryModel, filter: filter }
  #   ], (item, callback) ->
  # 
  #     authfilter = getModF(item.model, 'read')
  #     x = authfilter(authinfo)
  #     if !x
  #       callback("some kind of failure")
  #       return
  # 
  #     finalFilter = joinFilters(item.filter, x)
  #     if !finalFilter?
  #       callback('some other kind of failure')
  #       return
  # 
  #     callback(null, finalFilter)
  # 
  #   , (err, finalFilters) ->
  #     return callback(err) if err?
  #     originals.getOne.call this, primaryModel, { filter: finalFilters[0] }, (err) ->
  #       return callback(err) if err?
  #       originals.getMany(primaryModel, primaryId, propertyName, finalFilters[1], callback)
  # 
  # 
  # ['delMany', 'postMany'].forEach (manyMethod) ->
  # 
  #   newdb[manyMethod] = (primaryModel, primaryId, propertyName, secondaryId, callback) ->
  # 
  #     secondaryModel = null # figure this out from our metadata, and "primaryModel" and "propertyName"
  # 
  #     async.map [
  #       { model: primaryModel, filter: { id: primaryId } }
  #       { model: secondaryModel, filter: { id: secondaryId } }
  #     ], (item, callback) ->
  # 
  #       authfilter = getModF(item.model, 'write')
  #       x = authfilter(authinfo)
  #       if !x
  #         callback("some kind of failure")
  #         return
  # 
  #       finalFilter = joinFilters(item.filter, x)
  #       if !finalFilter?
  #         callback('some other kind of failure')
  #         return
  # 
  #       callback(null, finalFilter)
  # 
  #     , (err, finalFilters) ->
  #       return callback(err) if err?
  #       originals.getOne.call this, primaryModel, { filter: finalFilters[0] }, (err) ->
  #         return callback(err) if err?
  #         originals.getOne.call this, secondaryModel, { filter: finalFilters[1] }, (err) ->
  #           return callback(err) if err?
  #           originals[manyMethod](primaryModel, primaryId, propertyName, secondaryId, callback)
