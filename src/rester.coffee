gen = require './generic'
acm = require './access-controlled-manikin'
csv = require 'csv'
_ = require 'underscore'

{ClientError, AuthError} = acm

respond = (req, res, data, result) ->
  code = result || 200
  if req.query.metabody
    res.json { code: code, body: data, headers: 'Not implemented' }, 200
  else
    res.json data, code


toCSV = (input, callback) ->
  allKeys = _.flatten input.map(Object.keys)
  uniqKeys = _.uniq allKeys

  cb = (data, count) ->
    callback(null, data)

  csv().from(input).to.string(cb, {
    columns: uniqKeys
    header: true
    newColumns: true
    delimiter: ';'
  })



exports.acm = acm

exports.exec = (app, db, mods, getUserFromDbCore, config = {}) ->

  config.authRealm ?= 'rester'

  rr = gen.build(db, mods, getUserFromDbCore, config)

  res = rr.routes

  respondWithFormat = (req, res, data, err, format) ->
    if err instanceof AuthError
      res.header 'WWW-Authenticate', 'Basic realm="' + config.authRealm + '"'
      respond req, res, { err: (err?.message || err).toString() }, 401
    else if err instanceof ClientError
      respond req, res, { err: (err?.message || err).toString() }, 400
    else if err
      respond req, res, { err: err.toString() }, 500
    else
      if format == 'csv'
        toCSV data, (err, csvData) ->
          return respond(req, res, { err: err.toString() }, 500) if err
          res.header('content-type', 'text/csv; charset=utf-8')
          res.send(csvData)
      else
        respond(req, res, data)



  res.forEach (x) ->
    app[x.method].call app, x.route, (req, res) ->
      x.callback req, (err, data) ->
        format = 'json'
        format = 'csv' if req.headers.accept == 'text/csv'
        respondWithFormat(req, res, data, err, format)

    app[x.method].call app, x.route + '.csv', (req, res) ->
      x.callback req, (err, data) ->
        respondWithFormat(req, res, data, err, 'csv')



  app.get '/', (req, res) ->
    respond(req, res, {
      roots: rr.roots
      verbs: []
    })


  app.all '*', (req, res) ->
    respond(req, res, { err: 'No such resource' }, 400)
