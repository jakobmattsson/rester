_ = require 'underscore'
async = require 'async'
manikinTools = require 'manikin-tools'
acm = require './access-controlled-manikin'

propagate = (onErr, onSucc) ->
  (err, rest...) ->
    return onErr(err) if err?
    return onSucc(rest...)


exports.build = (manikin, mods, getUserFromDbCore, config = {}) ->


  # "mods" borde kunna hämtas som en funktion från "db". är det inte redan så till och med?
  # "request"-objektet som skickas in till getUserFromDbCore, vad måste det objektet uppfylla? Förslagsvis samma som rester.

  config.verbose ?= true
  returnedResult = []
  allMeta = manikinTools.getMeta(manikinTools.desugar(mods))

  getUserFromDb = (req, callback) ->
    return callback(null, req._cachedUser) if req._hasCachedUser
    getUserFromDbCore req, propagate callback, (result) ->
      req._hasCachedUser = true
      req._cachedUser = result
      callback(null, result)

  def = (method, route, callback) ->
    returnedResult.push
      method: method
      route: route
      callback: (req, cb) ->

        # What else should there be in q request object?
        req.params ?= {}

        try
          console.log(req.method, req.url) if config.verbose
          getUserFromDb req, propagate cb, (usr) ->
            callback(req, acm.build(manikin, mods, usr), cb)
        catch ex
          cb(new Error(ex.toString()))


  Object.keys(mods).forEach (modelName) ->

    owners = allMeta[modelName].owners
    manyToMany = allMeta[modelName].manyToMany

    def 'get', "/#{modelName}", (req, db, callback) ->
      db.list(modelName, req.query, callback)

    def 'get', "/#{modelName}/:id", (req, db, callback) ->
      db.getOne(modelName, { filter: { id: req.params.id } }, callback)

    def 'del', "/#{modelName}/:id", (req, db, callback) ->
      db.delOne(modelName, { id: req.params.id }, callback)

    def 'put', "/#{modelName}/:id", (req, db, callback) ->
      db.putOne(modelName, req.body, { id: req.params.id }, callback)

    def 'get', "/meta/#{modelName}", (req, db, callback) ->
      callback null,
        owns: allMeta[modelName].owns.map((x) -> x.name)
        fields: allMeta[modelName].fields

    def 'post', "/#{modelName}", (req, db, callback) ->
      db.post(modelName, req.body, callback)

    owners.forEach (owner) ->
      def 'get', "/#{owner.plur}/:id/#{modelName}", (req, db, callback) ->
        db.list(modelName, _.object([[owner.sing, req.params.id]]), callback)

      def 'post', "/#{owner.plur}/:id/#{modelName}", (req, db, callback) ->
        db.post(modelName, _.extend({}, req.body, _.object([[owner.sing, req.params.id]])), callback)

    manyToMany.forEach (many) ->
      def 'post', "/#{modelName}/:id/#{many.name}/:other", (req, db, callback) ->
        db.postMany(modelName, req.params.id, many.name, req.params.other, callback)

      def 'get', "/#{modelName}/:id/#{many.name}", (req, db, callback) ->
        db.getMany(modelName, req.params.id, many.name, {}, callback)

      def 'del', "/#{modelName}/:id/#{many.name}/:other", (req, db, callback) ->
        db.delMany(modelName, req.params.id, many.name, req.params.other, callback)

  {
    routes: returnedResult
    roots: Object.keys(mods).filter((name) -> allMeta[name].owners.length == 0)
  }
