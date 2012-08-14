_ = require 'underscore'
async = require 'async'
_.mixin require 'underscore.plus'

exports.respond = (req, res, data, result) ->
  if req.headers.origin
    res.header 'Access-Control-Allow-Origin', req.headers.origin
    res.header 'Access-Control-Allow-Credentials', 'true'
    res.header 'Access-Control-Allow-Headers', 'Authorization' # Maybe these: 'origin, authorization, accept' or req.headers['access-control-allow-headers']
    res.header 'Access-Control-Allow-Methods', 'POST, GET, OPTIONS, DELETE, PUT'

  code = result || 200

  if req.query.metabody
    res.json { code: code, body: data, headers: 'Not implemented' }, 200
  else
    res.json data, code

verbs = []

exports.verb = (app, route, middleware, callback) ->
  app.post '/' + route, middleware, callback
  verbs.push route

exports.exec = (app, db, getUserFromDbCore, mods) ->

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
    func = app[method]
    func.call app, route, preMid, (req, res) ->
      errHandler = (f) ->
        (err, data) ->
          if err
            exports.respond req, res, { err: err.toString() }, 400
            return
          f(data)

      try
        console.log(req.method, req.url)
        callback req, errHandler (data) ->
          async.reduce postMid, data, (memo, mid, callback) ->
            mid(req, data, callback)
          , errHandler (result) ->
            exports.respond req, res, result
      catch ex
        console.log(ex.message)
        console.log(ex.stack)
        exports.respond req, res, { err: 'Internal error: ' + ex.toString() }, 500

  naturalizeIn = (field) -> (req, res, next) ->
    if !field?
      req.queryFilter = {}
      req.queryFilter.id = req.params.id
      next()
    else
      req.queryFilter = {}
      req.queryFilter[field] = req.params.id
      next()

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

  db.getModels().forEach (modelName) ->

    owners = db.getOwners(modelName)
    manyToMany = db.getManyToMany(modelName)

    midFilter = (type) -> (req, res, next) ->
      authFuncs =
        read: mods[modelName].auth || -> {}
        write: mods[modelName].authWrite
        create: mods[modelName].authCreate
      authFuncs.write ?= authFuncs.read
      authFuncs.create ?= authFuncs.write

      getUserFromDb req, (err, user) ->
        if err
          callback err
          return
        filter = authFuncs[type](user)
        if !filter?
          res.header 'WWW-Authenticate', 'Basic realm="sally"'
          exports.respond req, res, { err: "unauthed" }, 401
          return

        req.queryFilter = joinFilters(filter, req.queryFilter)
        if !req.queryFilter?
          exports.respond req, res, { err: "No such id" }, 400
        else
          next()

    def2 'get', "/#{modelName}", [midFilter('read')], [naturalizeOut(mods[modelName].naturalId), fieldFilterMiddleware(mods[modelName].fieldFilter)], (req, callback) ->
      db.list modelName, req.queryFilter, callback

    def2 'get', "/#{modelName}/:id", [naturalizeIn(mods[modelName].naturalId), midFilter('read')], [naturalizeOut(mods[modelName].naturalId), fieldFilterMiddleware(mods[modelName].fieldFilter)], (req, callback) ->
      db.getOne modelName, req.queryFilter, callback

    def2 'del', "/#{modelName}/:id", [naturalizeIn(mods[modelName].naturalId), midFilter('write')], [naturalizeOut(mods[modelName].naturalId), fieldFilterMiddleware(mods[modelName].fieldFilter)], (req, callback) ->
      db.delOne modelName, req.queryFilter, callback

    def2 'put', "/#{modelName}/:id", [naturalizeIn(mods[modelName].naturalId), midFilter('write')], [naturalizeOut(mods[modelName].naturalId), fieldFilterMiddleware(mods[modelName].fieldFilter)], (req, callback) ->
      db.putOne modelName, req.body, req.queryFilter, callback

    def2 'get', "/meta/#{modelName}", [], [], (req, callback) ->
      callback null,
        owns: db.getOwnedModels(modelName).map((x) -> x.name)
        fields: db.getMetaFields(modelName)

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
          obj = _.makeObject(natId, req.params.id)
          db.getOne owner.plur, obj, (err, resObj) ->
            filter2 = _.makeObject(owner.sing, resObj.id)
            filter = joinFilters(filter, filter2)
            if !filter?
              callback('No such id')
              return
            db.list modelName, filter, callback
          return
        # </natural-id>

        filter = joinFilters(filter, _.makeObject(outer, id))
        if !filter?
          callback 'No such id'
          return

        db.list modelName, filter, callback


      def2 'post', "/#{modelName}", [midFilter('create')], [naturalizeOut(mods[modelName].naturalId), fieldFilterMiddleware(mods[modelName].fieldFilter)], (req, callback) ->
        data = _.extend({}, req.body, _.makeObject(owner.sing, req.params.id))

        # This doesn't seem to work with natural IDs.
        #
        # <natural-id>
        # natId = mods[owner.plur].naturalId
        # if natId?
        #   obj = _.makeObject(natId, req.params.id)
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
          db.post modelName, data, callback
        else
          callback('Missing owner')

      def2 'post', "/#{owner.plur}/:id/#{modelName}", [midFilter('create')], [naturalizeOut(mods[modelName].naturalId), fieldFilterMiddleware(mods[modelName].fieldFilter)], (req, callback) ->
        data = _.extend({}, req.body, _.makeObject(owner.sing, req.params.id))

        # <natural-id>
        natId = mods[owner.plur].naturalId
        if natId?
          obj = _.makeObject(natId, req.params.id)
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
      def2 'post', "/#{modelName}/:id/#{many.name}/:other", [], [], (req, callback) ->
        db.postMany modelName, req.params.id, many.name, many.ref, req.params.other, callback

      def2 'post', "/#{many.name}/:other/#{modelName}/:id", [], [], (req, callback) ->
        db.postMany modelName, req.params.id, many.name, many.ref, req.params.other, callback

      def2 'get', "/#{modelName}/:id/#{many.name}", [], [], (req, callback) ->
        db.getMany modelName, req.params.id, many.name, callback

      def2 'get', "/#{many.name}/:id/#{modelName}", [], [], (req, callback) ->
        db.getManyBackwards modelName, req.params.id, many.name, callback

      def2 'del', "/#{modelName}/:id/#{many.name}/:other", [], [], (req, callback) ->
        db.getOne many.ref, { id: req.params.other }, (err, data) ->
          db.delMany modelName, req.params.id, many.name, many.ref, req.params.other, (innerErr) ->
            callback(err || innerErr, data)

      def2 'del', "/#{many.name}/:other/#{modelName}/:id", [], [], (req, callback) ->
        db.getOne modelName, { id: req.params.id }, (err, data) ->
          db.delMany modelName, req.params.id, many.name, many.ref, req.params.other, (innerErr) ->
            callback(err || innerErr, data)

  def2 'get', '/', [], [], (req, callback) ->
    callback null,
      roots: db.getModels().filter((name) -> db.getOwners(name).length == 0)
      verbs: verbs

  def2 'options', '*', [], [], (req, callback) ->
    callback null, {}

  def2 'all', '*', [], [], (req, callback) ->
    callback 'No such resource'