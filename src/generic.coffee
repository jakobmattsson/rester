_ = require 'underscore'
async = require 'async'
manikinTools = require 'manikin-tools'


class AuthError extends Error
  constructor: (msg) -> @message = msg

class ClientError extends Error
  constructor: (msg) -> @message = msg


exports.AuthError = AuthError
exports.ClientError = ClientError

exports.build = (db, mods, getUserFromDbCore, config = {}) ->

  # "mods" borde kunna hämtas som en funktion från "db". är det inte redan så till och med?
  # "request"-objektet som skickas in till getUserFromDbCore, vad måste det objektet uppfylla? Förslagsvis samma som rester.

  config.authRealm ?= 'rester'
  config.verbose ?= true

  returnedResult = []

  allMeta = manikinTools.getMeta(mods)

  getUserFromDb = (req, callback) ->
    if req._hasCachedUser
      callback(null, req._cachedUser)
      return
    getUserFromDbCore req, (err, result) ->
      if err
        callback(err)
        return
      req._hasCachedUser = true
      req._cachedUser = result
      callback(null, result)

  def2 = (method, route, preMid, postMid, callback) ->
    routeHandler = (req, cbb) ->

      # What else should there be in q request object?
      req.params ?= {}

      errHandler = (f) ->
        (err, data) ->
          if err
            cbb(err)
            return
          f(data)

      try
        console.log(req.method, req.url) if config.verbose

        async.reduce preMid, null, (m1, m2, callback) ->
          m2(req, callback)
        , errHandler ->
          callback req, errHandler (data) ->
            async.reduce postMid, data, (memo, mid, callback) ->
              mid(req, data, callback)
            , errHandler (result) ->
              cbb(null, result)
      catch ex
        cbb(new Error(ex.toString()))

    returnedResult.push({
      method: method
      route: route
      callback: routeHandler
    })


  naturalizeIn = (field) -> (req, callback) ->
    if !field?
      req.queryFilter = {}
      req.queryFilter.id = req.params.id
    else
      req.queryFilter = {}
      req.queryFilter[field] = req.params.id
    callback()


  joinFilters = (filter1, filter2) ->
    filter1 ?= {}
    filter2 ?= {}
    dupKeys = _.intersection(Object.keys(filter1), Object.keys(filter2))
    return undefined if dupKeys.some (name) -> filter1[name]?.toString() != filter2[name]?.toString()
    _.extend({}, filter1, filter2)

  fieldFilterMiddleware = (fieldFilter) -> (req, outdata, callback) ->

    if !fieldFilter
      callback(null, outdata)
      return

    getUserFromDb req, (err, user) ->
      if err
        callback err
        return

      evaledFilter = fieldFilter(user)

      if Array.isArray(outdata)
        outdata.forEach (x) ->
          evaledFilter.forEach (filter) ->
            delete x[filter]
      else
        evaledFilter.forEach (filter) ->
          delete outdata[filter]

      callback(null, outdata)

  naturalizeOut = (field) -> (req, data, callback) ->
    if !field?
      callback(null, data)
      return

    transform = (d) ->
      d.id = d[field]
      d

    if Array.isArray data
      data = data.map(transform)
    else
      data = transform(data)

    callback null, data

  Object.keys(mods).forEach (modelName) ->

    owners = allMeta[modelName].owners
    manyToMany = allMeta[modelName].manyToMany

    midFilter = (type) -> (req, cb) ->
      authFuncs =
        read: mods[modelName].auth || -> {}
        write: mods[modelName].authWrite
        create: mods[modelName].authCreate
      authFuncs.write ?= authFuncs.read
      authFuncs.create ?= authFuncs.write

      getUserFromDb req, (err, user) ->
        if err
          cb(new AuthError('unauthed'))
          return
        filter = authFuncs[type](user)
        if !filter?
          cb(new AuthError('unauthed'))
          return

        req.queryFilter = joinFilters(filter, req.queryFilter)
        if !req.queryFilter?
          cb(new ClientError('No such id'))
        else
          cb()

    def2 'get', "/#{modelName}", [midFilter('read')], [naturalizeOut(mods[modelName].naturalId), fieldFilterMiddleware(mods[modelName].fieldFilter)], (req, callback) ->
      db.list modelName, req.queryFilter, callback

    def2 'get', "/#{modelName}/:id", [naturalizeIn(mods[modelName].naturalId), midFilter('read')], [naturalizeOut(mods[modelName].naturalId), fieldFilterMiddleware(mods[modelName].fieldFilter)], (req, callback) ->
      db.getOne modelName, { filter: req.queryFilter }, callback

    def2 'del', "/#{modelName}/:id", [naturalizeIn(mods[modelName].naturalId), midFilter('write')], [naturalizeOut(mods[modelName].naturalId), fieldFilterMiddleware(mods[modelName].fieldFilter)], (req, callback) ->
      db.delOne modelName, req.queryFilter, callback

    def2 'put', "/#{modelName}/:id", [naturalizeIn(mods[modelName].naturalId), midFilter('write')], [naturalizeOut(mods[modelName].naturalId), fieldFilterMiddleware(mods[modelName].fieldFilter)], (req, callback) ->
      db.putOne modelName, req.body, req.queryFilter, callback

    def2 'get', "/meta/#{modelName}", [], [], (req, callback) ->
      callback null,
        owns: allMeta[modelName].owns.map((x) -> x.name)
        fields: allMeta[modelName].fields

    if owners.length == 0
      def2 'post', "/#{modelName}", [midFilter('create')], [naturalizeOut(mods[modelName].naturalId), fieldFilterMiddleware(mods[modelName].fieldFilter)], (req, callback) ->
        db.post modelName, req.body, callback

    owners.forEach (owner) ->
      def2 'get', "/#{owner.plur}/:id/#{modelName}", [midFilter('read')], [naturalizeOut(mods[modelName].naturalId), fieldFilterMiddleware(mods[modelName].fieldFilter)], (req, callback) ->
        filter = req.queryFilter
        id = req.params.id
        outer = owner.sing

        # <natural-id>
        natId = mods[owner.plur].naturalId
        if natId?
          obj = _.object([[natId, req.params.id]])
          db.getOne owner.plur, obj, (err, resObj) ->
            filter2 = _.object([[owner.sing, resObj.id]])
            filter = joinFilters(filter, filter2)
            if !filter?
              callback('No such id')
              return
            db.list modelName, filter, callback
          return
        # </natural-id>

        filter = joinFilters(filter, _.object([[outer, id]]))
        if !filter?
          callback 'No such id'
          return

        db.list modelName, filter, callback


      def2 'post', "/#{modelName}", [midFilter('create')], [naturalizeOut(mods[modelName].naturalId), fieldFilterMiddleware(mods[modelName].fieldFilter)], (req, callback) ->
        data = req.body

        # This doesn't seem to work with natural IDs.
        #
        # <natural-id>
        # natId = mods[owner.plur].naturalId
        # if natId?
        #   obj = _.object([[natId, req.params.id]])
        #   db.getOne owner.plur, obj, (err, resObj) ->
        #     if err
        #       callback(err)
        #       return
        #
        #     data[owner.sing] = resObj.id
        #     db.post modelName, data, callback
        #   return
        # </natural-id>

        if req.queryFilter[owner.sing]?
          data[owner.sing] = req.queryFilter[owner.sing]
        else if !data[owner.sing]?
          return callback('Missing owner')

        db.post modelName, data, callback

      def2 'post', "/#{owner.plur}/:id/#{modelName}", [midFilter('create')], [naturalizeOut(mods[modelName].naturalId), fieldFilterMiddleware(mods[modelName].fieldFilter)], (req, callback) ->
        data = _.extend({}, req.body, _.object([[owner.sing, req.params.id]]))

        # <natural-id>
        natId = mods[owner.plur].naturalId
        if natId?
          obj = _.object([[natId, req.params.id]])
          db.getOne owner.plur, obj, (err, resObj) ->
            if err
              callback(err)
              return

            data[owner.sing] = resObj.id
            db.post modelName, data, callback
          return
        # </natural-id>

        db.post modelName, data, callback

    manyToMany.forEach (many) ->
      def2 'post', "/#{modelName}/:id/#{many.name}/:other", [midFilter('write')], [], (req, callback) ->
        db.postMany modelName, req.params.id, many.name, req.params.other, callback

      def2 'get', "/#{modelName}/:id/#{many.name}", [midFilter('read')], [], (req, callback) ->
        db.getMany modelName, req.params.id, many.name, callback

      def2 'del', "/#{modelName}/:id/#{many.name}/:other", [midFilter('write')], [], (req, callback) ->
        db.getOne many.ref, { id: req.params.other }, (err, data) ->
          db.delMany modelName, req.params.id, many.name, req.params.other, (innerErr) ->
            callback(err || innerErr, data)

  {
    routes: returnedResult
    roots: Object.keys(mods).filter((name) -> allMeta[name].owners.length == 0)
  }
