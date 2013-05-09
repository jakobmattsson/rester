gen = require './generic'

{ClientError, AuthError} = gen

respond = (req, res, data, result) ->
  code = result || 200
  if req.query.metabody
    res.json { code: code, body: data, headers: 'Not implemented' }, 200
  else
    res.json data, code


exports.exec = (app, db, mods, getUserFromDbCore, config = {}) ->

  rr = gen.build(db, mods, getUserFromDbCore, config)

  res = rr.routes

  res.forEach (x) ->
    # console.log(x.method, x.route)
    app[x.method].call app, x.route, (req, res) ->

      x.callback req, (err, data) ->

        if err instanceof AuthError
          res.header 'WWW-Authenticate', 'Basic realm="' + config.authRealm + '"'
          respond req, res, { err: (err?.message || err).toString() }, 401
        else if err instanceof ClientError
          respond req, res, { err: (err?.message || err).toString() }, 400
        else if err
          respond req, res, { err: err.toString() }, 500
        else
          respond(req, res, data)



  app.get '/', (req, res) ->
    respond(req, res, {
      roots: rr.roots
      verbs: []
    })


  app.all '*', (req, res) ->
    respond(req, res, { err: 'No such resource' }, 400)
