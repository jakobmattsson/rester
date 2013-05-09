jscov = require 'jscov'
rester = require jscov.cover('..', 'lib', 'rester')
should = require 'should'
express = require 'express'
manikin = require 'manikin-mongodb'
request = require 'request'
mongojs = require 'mongojs'
_ = require 'underscore'
Q = require 'q'



qRequest = (config = {}) ->
  (params) ->
    deferred = Q.defer()

    if typeof params == 'string'
      params = { url: params }

    if config.baseUrl? || params.url?
      params = _.extend({}, params, { url: (config.url ? '') + (params.url ? '') })

    request params, (err, res, body) ->
      if err
        deferred.reject(err)
      else
        jsonBody = null

        if typeof body == 'string'
          try
            jsonBody = JSON.parse(body)
          catch ex
            jsonBody = {}
        else
          jsonBody = body

        deferred.resolve({ res: res, body: body, json: jsonBody  })
    deferred.promise



it "should have the right methods", ->
  rester.should.have.keys [
    'exec'
    # 'verb'
    # 'respond'
  ]



it "should do things", (done) ->

  mongodb = 'mongodb://localhost/rester-test'
  port = 1337
  req = qRequest({ url: 'http://localhost:' + port })

  # define the app
  app = express()
  app.use express.bodyParser()
  app.use express.responseTime()

  # define the auth
  userFromDb = (req, callback) -> callback(null, {})

  # define the db
  db = manikin.create()
  models =
    people:
      fields:
        name: 'string'
        age: 'number'
    pets:
      owners: person: 'people'
      fields:
        name: 'string'
        race: 'string'
    foods:
      fields:
        name: 'string'
        eatenBy: { type: 'hasMany', model: 'pets', inverseName: 'eats' }

  # run tests
  mongojs.connect(mongodb).dropDatabase ->
    db.connect mongodb, models, ->

      rester.exec(app, db, models, userFromDb, { verbose: false })
      app.listen(port)

      s = {}

      req
        url: '/'
      .then ({ json }) ->
        json.should.eql
          roots: ['people', 'foods']
          verbs: []

      # Inserting and updating some food
      # ================================
      .then ->
        req '/foods'
      .then ({ json }) ->
        json.should.eql []
      .then ->
        req { method: 'POST', url: '/foods', json: { name: 'f0' } }
      .then ({ json }) ->
        s.food0 = json
      .then ->
        req { method: 'POST', url: '/foods', json: { name: 'testFood' } }
      .then ({ json }) ->
        s.food1 = json
        json.should.have.keys ['id', 'name', 'eatenBy']
        _(json).omit('id').should.eql { name: 'testFood', eatenBy: [] }
      .then ->
        req '/foods'
      .then ({ json }) ->
        json.map((x) -> _(x).omit('id')).should.eql [ { name: 'f0', eatenBy: [] }, { name: 'testFood', eatenBy: [] } ]
      .then ->
        req "/foods/#{s.food1.id}"
      .then ({ json }) ->
        json.should.eql { id: s.food1.id, name: 'testFood', eatenBy: [] }
      .then ->
        req { method: 'PUT', url: "/foods/#{s.food1.id}", json: { name: 'f1' } }
      .then ({ json }) ->
        json.should.eql { id: s.food1.id, name: 'f1', eatenBy: [] }

      # Inserting and updating some people and pets
      # ===========================================
      .then ->
        req { method: 'POST', url: '/people', json: { name: 'jakob', age: 27 } }
      .then ({ json }) ->
        s.jakob = json
      .then ->
        req { method: 'POST', url: '/people', json: { name: 'julia', age: 26 } }
      .then ({ json }) ->
        s.julia = json
        json.should.have.keys ['id', 'name', 'age']
        _(json).omit('id').should.eql { name: 'julia', age: 26 }
      .then ->
        req { method: 'POST', url: "/people/#{s.julia.id}/pets", json: { name: 'sixten', race: 'cat' } }
      .then ({ json }) ->
        s.sixten = json
        json.should.have.keys ['id', 'name', 'race', 'person', 'eats']
        _(json).omit('id').should.eql { name: 'sixten', race: 'cat', person: s.julia.id, eats: [] }
      .then ->
        req { method: 'POST', url: "/pets", json: { name: 'dog', race: 'dog', person: s.julia.id } }
      .then ({ json }) ->
        s.dog = json
      .then ->
        req "/people/#{s.julia.id}/pets"
      .then ({ json }) ->
        json.should.eql [
          id: s.sixten.id
          name: 'sixten'
          race: 'cat'
          person: s.julia.id
          eats: []
        ,
          id: s.dog.id
          name: 'dog'
          race: 'dog'
          person: s.julia.id
          eats: []
        ]
      .then ->
        req { url: "/pets/#{s.dog.id}", method: 'DELETE' }
      .then ({ json }) ->
        json.should.eql
          id: s.dog.id
          name: 'dog'
          race: 'dog'
          person: s.julia.id
          eats: []

      # Doing some many to many
      # =======================
      .then ->
        req { url: "/foods/#{s.food1.id}/eatenBy/#{s.sixten.id}", method: 'POST' }
      .then ({ json }) ->
        json.should.eql { status: 'inserted' }
      .then ->
        req { url: "/foods/#{s.food0.id}/eatenBy/#{s.sixten.id}", method: 'POST' }
      .then ({ json }) ->
        json.should.eql { status: 'inserted' }
      .then ->
        req "/pets/#{s.sixten.id}"
      .then ({ json }) ->
        json.should.eql
          id: s.sixten.id
          name: 'sixten'
          race: 'cat'
          person: s.julia.id
          eats: [s.food1.id, s.food0.id]
      .then ->
        req "/pets/#{s.sixten.id}/eats"
      .then ({ json }) ->
        json.should.eql [
          name: 'f1'
          eatenBy: [s.sixten.id]
          id: s.food1.id
        ,
          name: 'f0'
          eatenBy: [s.sixten.id]
          id: s.food0.id
        ]
      .then ->
        req "/foods/#{s.food0.id}/eatenBy"
      .then ({ json }) ->
        json.should.eql [
          id: s.sixten.id
          name: 'sixten'
          race: 'cat'
          person: s.julia.id
          eats: [s.food1.id, s.food0.id]
        ]
      .then ->
        req { url: "/pets/#{s.sixten.id}/eats/#{s.food0.id}", method: 'DELETE' }
      .then ->
        req "/pets/#{s.sixten.id}"
      .then ({ json }) ->
        json.should.eql
          id: s.sixten.id
          name: 'sixten'
          race: 'cat'
          person: s.julia.id
          eats: [s.food1.id]
      .then ->
        req "/foods/#{s.food0.id}/eatenBy"
      .then ({ json }) ->
        json.should.eql []

      # Cascading
      # =========
      .then ->
        req '/people'
      .then ({ json }) ->
        json.length.should.eql 2
      .then ->
        req '/foods'
      .then ({ json }) ->
        json.length.should.eql 2
      .then ->
        req '/pets'
      .then ({ json }) ->
        json.length.should.eql 1
      .then ->
        req { url: "/people/#{s.julia.id}", method: 'DELETE' }
      .then ->
        req '/people'
      .then ({ json }) ->
        json.length.should.eql 1
      .then ->
        req '/foods'
      .then ({ json }) ->
        json.should.eql [
          name: 'f1'
          eatenBy: []
          id: s.food1.id
        ,
          name: 'f0'
          eatenBy: []
          id: s.food0.id
        ]
      .then ->
        req '/pets'
      .then ({ json }) ->
        json.length.should.eql 0


      # Finishing and catching failures
      # ===============================
      .then ->
        done()
      .fail(done)
