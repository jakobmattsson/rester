jscov = require 'jscov'
generic = require jscov.cover('..', 'lib', 'generic')
should = require 'should'


# lägg till en route för /top/:id/deeper (där deeper är mer än ett steg ner i own-kedjan)


setup = (models, callback) ->

  db = {}
  config = {
    authRealm: 'apa'
    verbose: false
  }

  res = callback(null, generic.build(db, models, (->), config))

listRoutes = (res) ->
  res.map(({method, route}) -> method + ' ' + route ).sort()






describe 'build', ->

  it "creates the proper routes for a single resource", (done) ->

    models =
      people:
        fields: {}

    setup models, (err, res) ->

      listRoutes(res.routes).should.eql [
        'del /people/:id'
        'get /meta/people'
        'get /people'
        'get /people/:id'
        'post /people'
        'put /people/:id'
      ]

      done()



  it "creates the proper routes for multiple resource", (done) ->

    models =
      people: { fields: {} }
      pets: { fields: {} }

    setup models, (err, res) ->

      listRoutes(res.routes).should.eql [
        'del /people/:id'
        'del /pets/:id'
        'get /meta/people'
        'get /meta/pets'
        'get /people'
        'get /people/:id'
        'get /pets'
        'get /pets/:id'
        'post /people'
        'post /pets'
        'put /people/:id'
        'put /pets/:id'
      ]

      done()



  it "creates the proper routes for owned resources", (done) ->

    models =
      people: { fields: {} }
      pets: {
        owners: person: 'people'
        fields: {}
      }

    setup models, (err, res) ->

      listRoutes(res.routes).should.eql [
        'del /people/:id'
        'del /pets/:id'
        'get /meta/people'
        'get /meta/pets'
        'get /people'
        'get /people/:id'
        'get /people/:id/pets'
        'get /pets'
        'get /pets/:id'
        'post /people'
        'post /people/:id/pets'
        'post /pets'
        'put /people/:id'
        'put /pets/:id'
      ]

      done()



  it "creates the proper routes for deeply owned resources", (done) ->

    models =
      accounts: { fields: {} }
      people: {
        owners: account: 'accounts'
        fields: {}
      }
      pets: {
        owners: person: 'people'
        fields: {}
      }

    setup models, (err, res) ->

      listRoutes(res.routes).should.eql [
        'del /accounts/:id'
        'del /people/:id'
        'del /pets/:id'
        'get /accounts'
        'get /accounts/:id'
        'get /accounts/:id/people'
        'get /meta/accounts'
        'get /meta/people'
        'get /meta/pets'
        'get /people'
        'get /people/:id'
        'get /people/:id/pets'
        'get /pets'
        'get /pets/:id'
        'post /accounts'
        'post /accounts/:id/people'
        'post /people'
        'post /people/:id/pets'
        'post /pets'
        'put /accounts/:id'
        'put /people/:id'
        'put /pets/:id'
      ]

      done()



  it "creates the proper routes for hasOnes (none, that is)", (done) ->

    models =
      people: { fields: {} }
      pets: {
        fields: {
          person: {
            type: 'hasOne'
            model: 'people'
          }
        }
      }

    setup models, (err, res) ->

      listRoutes(res.routes).should.eql [
        'del /people/:id'
        'del /pets/:id'
        'get /meta/people'
        'get /meta/pets'
        'get /people'
        'get /people/:id'
        'get /pets'
        'get /pets/:id'
        'post /people'
        'post /pets'
        'put /people/:id'
        'put /pets/:id'
      ]

      done()



  it "creates the proper routes for hasMany", (done) ->

    models =
      people: { fields: {} }
      pets: {
        fields: {
          owners: {
            type: 'hasMany'
            model: 'people'
            inverseName: 'ownedPets'
          }
        }
      }

    setup models, (err, res) ->

      listRoutes(res.routes).should.eql [
        'del /people/:id'
        'del /people/:id/ownedPets/:other'
        'del /pets/:id'
        'del /pets/:id/owners/:other'
        'get /meta/people'
        'get /meta/pets'
        'get /people'
        'get /people/:id'
        'get /people/:id/ownedPets'
        'get /pets'
        'get /pets/:id'
        'get /pets/:id/owners'
        'post /people'
        'post /people/:id/ownedPets/:other'
        'post /pets'
        'post /pets/:id/owners/:other'
        'put /people/:id'
        'put /pets/:id'
      ]

      done()
