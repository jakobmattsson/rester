_ = require 'underscore'
async = require 'async'
manikinTools = require 'manikin-tools'



class AuthError extends Error
  constructor: (msg) -> @message = msg

class ClientError extends Error
  constructor: (msg) -> @message = msg



joinFilters = (filter1, filter2) ->
  return undefined if !filter1? || !filter2?
  dupKeys = _.intersection(Object.keys(filter1), Object.keys(filter2))
  return undefined if dupKeys.some (name) -> filter1[name]?.toString() != filter2[name]?.toString()
  _.extend({}, filter1, filter2)


propagate = (onErr, onSucc) ->
  (err, rest...) ->
    return onErr(err) if err?
    return onSucc(rest...)


exports.AuthError = AuthError
exports.ClientError = ClientError
exports.build = (db, mods, authinfo) ->

  originals = db

  newdb = {}
  newdb.connect = originals.connect
  newdb.close = originals.close

  getModF = (model, func) ->
    funcs = {
      read: mods[model].auth || -> {}
      write: mods[model].authWrite
      create: mods[model].authCreate
    }
    funcs.write ?= funcs.read
    funcs.create ?= funcs.write
    funcs[func]



  stuff = (model, filter, level, callback) ->
    authfilter = getModF(model, level)
    x = authfilter(authinfo)
    if !x
      callback(new AuthError('unauthed'))
      return

    finalFilter = joinFilters(filter, x)
    if !finalFilter?
      callback(new AuthError('unauthed'))
      return

    callback(null, finalFilter)



  newdb.post = (model, indata, callback) ->
    stuff model, {}, 'create', propagate callback, (finalFilter) =>
      originals.post.call(this, model, indata, callback)

  newdb.list = (model, filter, callback) ->
    stuff model, filter, 'read', propagate callback, (finalFilter) =>
      originals.list.call(this, model, finalFilter, callback)

  newdb.getOne = (model, config, callback) ->
    stuff model, config.filter || {}, 'read', propagate callback, (finalFilter) =>
      originals.getOne.call(this, model, _.extend({}, config, { filter: finalFilter }), callback)

  newdb.delOne = (model, filter, callback) ->
    stuff model, filter, 'write', propagate callback, (finalFilter) =>
      originals.delOne.call(this, model, finalFilter, callback)

  newdb.putOne = (model, data, filter, callback) ->
    stuff model, filter, 'write', propagate callback, (finalFilter) =>
      originals.putOne.call(this, model, data, finalFilter, callback)



  newdb.getMany = (primaryModel, primaryId, propertyName, filter, callback) ->
    {ref, inverseName} = manikinTools.getMeta(mods)[primaryModel].manyToMany.filter((x) -> x.name == propertyName)[0]

    secondaryModel = ref

    async.map [
      { model: primaryModel, filter: { id: primaryId } }
      { model: secondaryModel, filter: filter }
    ], (item, callback) ->
      stuff item.model, item.filter, 'read', callback
    , propagate callback, (finalFilters) =>
      originals.getOne.call this, primaryModel, { filter: finalFilters[0] }, propagate callback, ->
        originals.getMany(primaryModel, primaryId, propertyName, finalFilters[1], callback)



  ['delMany', 'postMany'].forEach (manyMethod) ->

    newdb[manyMethod] = (primaryModel, primaryId, propertyName, secondaryId, callback) ->
      {ref, inverseName} = manikinTools.getMeta(mods)[primaryModel].manyToMany.filter((x) -> x.name == propertyName)[0]
      secondaryModel = ref

      async.map [
        { model: primaryModel, filter: { id: primaryId } }
        { model: secondaryModel, filter: { id: secondaryId } }
      ], (item, callback) ->
        stuff item.model, item.filter, 'write', callback
      , propagate callback, (finalFilters) =>
        originals.getOne.call this, primaryModel, { filter: finalFilters[0] }, propagate callback, =>
          originals.getOne.call this, secondaryModel, { filter: finalFilters[1] }, propagate callback, ->
            originals[manyMethod](primaryModel, primaryId, propertyName, secondaryId, callback)

  newdb
