jscov = require 'jscov'
sinon = require 'sinon'
chai = require 'chai'
sinonChai = require 'sinon-chai'

chai.use sinonChai
expect = chai.expect

generic = require jscov.cover('..', 'lib', 'generic')

noErr = (f) -> (err, rest...) ->
  expect(err?).to.eql false
  f(rest...)


callRoute = (res, met, rot, req, callback) ->
  matches = res.routes.filter(({ method, route }) -> method == met && route == rot)
  expect(matches.length).to.eql 1
  matches[0].callback(req, callback)



describe 'the list-operation', ->

  it "invokes correctly when there is no auth-restriction", (done) ->
    models = { people: {} }
    result = Math.random()
    db = { list: sinon.mock().yieldsAsync(undefined, result) }
    auth = sinon.stub().yieldsAsync()
    res = generic.build(db, models, auth, { verbose: false })

    callRoute res, 'get', '/people', { }, noErr (data) ->
      expect(db.list).calledWith('people', { })
      expect(data).to.eql result
      done()



  it "invokes correctly when the user is partially authorized", (done) ->
    models =
      people:
        auth: -> { x: 1 }

    result = Math.random()
    db = { list: sinon.mock().yieldsAsync(null, result) }
    auth = sinon.stub().yieldsAsync()
    res = generic.build(db, models, auth, { verbose: false })
    callRoute res, 'get', '/people', {}, noErr (data) ->
      expect(db.list).calledWith('people', { x: 1 })
      expect(data).to.eql result
      done()



  it "invokes correctly when the user is not authorized", (done) ->
    models = {
      people: {
        auth: -> null
      }
    }
    auth = sinon.stub().yieldsAsync()
    res = generic.build(null, models, auth, { verbose: false })
    callRoute res, 'get', '/people', {}, (err, data) ->
      expect(err.message).to.eql 'unauthed'
      expect(data).to.eql undefined
      done()



describe 'the get-operation', ->

  it "invokes correctly when there is no auth-restriction", (done) ->
    models = { people: {} }
    result = Math.random()
    db = { getOne: sinon.mock().yieldsAsync(null, { res: result }) }
    auth = sinon.stub().yieldsAsync()
    res = generic.build(db, models, auth, { verbose: false })

    callRoute res, 'get', '/people/:id', { params: { id: 123 } }, noErr (data) ->
      expect(db.getOne).calledWith('people', { filter: { id: 123 } })
      expect(data).to.eql { res: result }
      done()



  it "invokes correctly when the user is partially authorized", (done) ->
    models =
      people:
        auth: -> { x: 1 }

    result = Math.random()
    db = { getOne: sinon.mock().yieldsAsync(null, { res: result }) }
    auth = sinon.stub().yieldsAsync()
    res = generic.build(db, models, auth, { verbose: false })
    callRoute res, 'get', '/people/:id', { params: { id: 456 } }, noErr (data) ->
      expect(db.getOne).calledWith('people', { filter: { x: 1, id: 456 } })
      expect(data).to.eql { res: result }
      done()



  it "invokes correctly when the user is not authorized", (done) ->
    models = {
      people: {
        auth: -> null
      }
    }
    auth = sinon.stub().yieldsAsync()
    res = generic.build(null, models, auth, { verbose: false })
    callRoute res, 'get', '/people/:id', { params: { id: 789 } }, (err, data) ->
      expect(err.message).to.eql 'unauthed'
      expect(data).to.eql undefined
      done()




describe 'the put-operation', ->

  it "invokes correctly when there is no auth-restriction", (done) ->
    models = { people: {} }
    result = Math.random()
    db = { putOne: sinon.mock().yieldsAsync(null, { r: result }) }
    auth = sinon.stub().yieldsAsync()
    res = generic.build(db, models, auth, { verbose: false })

    callRoute res, 'put', '/people/:id', { params: { id: 123 }, body: { v1: 100, v2: 200 }  }, noErr (data) ->
      expect(db.putOne).calledWith('people', { v1: 100, v2: 200 }, { id: 123 })
      expect(data).to.eql { r: result }
      done()



  it "invokes correctly when the user is partially authorized", (done) ->
    models =
      people:
        auth: -> { x: 1 }

    result = Math.random()
    db = { putOne: sinon.mock().yieldsAsync(undefined, { result }) }
    auth = sinon.stub().yieldsAsync()
    res = generic.build(db, models, auth, { verbose: false })
    callRoute res, 'put', '/people/:id', { params: { id: 456 }, body: { v1: 100, v2: 200 }  }, noErr (data) ->
      expect(db.putOne).calledWith('people', { v1: 100, v2: 200 }, { x: 1, id: 456 })
      expect(data).to.eql { result: result }
      done()



  it "invokes correctly when the user is not authorized", (done) ->
    models = {
      people: {
        auth: -> null
      }
    }
    auth = sinon.stub().yieldsAsync()
    res = generic.build(null, models, auth, { verbose: false })
    callRoute res, 'put', '/people/:id', { params: { id: 789 }, body: { v1: 100, v2: 200 } }, (err, data) ->
      expect(err.message).to.eql 'unauthed'
      expect(data).to.eql undefined
      done()






describe 'the del-operation', ->

  it "invokes correctly when there is no auth-restriction", (done) ->
    models = { people: {} }
    result = Math.random()
    db = { delOne: sinon.mock().yieldsAsync(null, { res: result }) }
    auth = sinon.stub().yieldsAsync()
    res = generic.build(db, models, auth, { verbose: false })

    callRoute res, 'del', '/people/:id', { params: { id: 123 } }, noErr (data) ->
      expect(db.delOne).calledWith('people', { id: 123 })
      expect(data).to.eql { res: result }
      done()



  it "invokes correctly when the user is partially authorized", (done) ->
    models =
      people:
        auth: -> { x: 1 }

    result = Math.random()
    db = { delOne: sinon.mock().yieldsAsync(null, { res: result }) }
    auth = sinon.stub().yieldsAsync()
    res = generic.build(db, models, auth, { verbose: false })
    callRoute res, 'del', '/people/:id', { params: { id: 456 } }, noErr (data) ->
      expect(db.delOne).calledWith('people', { x: 1, id: 456 })
      expect(data).to.eql { res: result }
      done()



  it "invokes correctly when the user is not authorized", (done) ->
    models = {
      people: {
        auth: -> null
      }
    }
    auth = sinon.stub().yieldsAsync()
    res = generic.build(null, models, auth, { verbose: false })
    callRoute res, 'del', '/people/:id', { params: { id: 789 } }, (err, data) ->
      expect(err.message).to.eql 'unauthed'
      expect(data).to.eql undefined
      done()

















describe "the auth-function of the model gets passed the result of the getUser function", ->

  it "for the LIST-operation", (done) ->
    models = people: auth: sinon.mock().returns({})
    db = list: sinon.stub().yieldsAsync()
    auth = (req, callback) -> callback(null, { name: 'foobar' })

    res = generic.build(db, models, auth, { verbose: false })
    callRoute res, 'get', '/people', { }, ->
      expect(models.people.auth).calledWithExactly({ name: 'foobar' })
      done()

  it "for the GET-operation", (done) ->
    models = people: auth: sinon.mock().returns({})
    db = get: sinon.stub().yieldsAsync()
    auth = (req, callback) -> callback(null, { name: 'foobar' })

    res = generic.build(db, models, auth, { verbose: false })
    callRoute res, 'get', '/people/:id', { }, ->
      expect(models.people.auth).calledWithExactly({ name: 'foobar' })
      done()

  it "for the DELETE-operation", (done) ->
    models = people: authWrite: sinon.mock().returns({})
    db = get: sinon.stub().yieldsAsync()
    auth = (req, callback) -> callback(null, { name: 'foobar' })

    res = generic.build(db, models, auth, { verbose: false })
    callRoute res, 'del', '/people/:id', { }, ->
      expect(models.people.authWrite).calledWithExactly({ name: 'foobar' })
      done()

  it "for the DELETE-operation, falling back to the read-auth function", (done) ->
    models = people: auth: sinon.mock().returns({})
    db = get: sinon.stub().yieldsAsync()
    auth = (req, callback) -> callback(null, { name: 'foobar' })

    res = generic.build(db, models, auth, { verbose: false })
    callRoute res, 'del', '/people/:id', { }, ->
      expect(models.people.auth).calledWithExactly({ name: 'foobar' })
      done()

  it "for the meta-operation", (done) ->
    models = people: auth: sinon.mock().returns({})
    db = get: sinon.stub().yieldsAsync()
    auth = (req, callback) -> callback(null, { name: 'foobar' })

    res = generic.build(db, models, auth, { verbose: false })
    callRoute res, 'get', '/meta/people', { }, ->
      expect(models.people.auth).notCalled
      done()

  it "for the POST-operation", (done) ->
    models = people: authCreate: sinon.mock().returns({})
    db = get: sinon.stub().yieldsAsync()
    auth = (req, callback) -> callback(null, { name: 'foobar' })

    res = generic.build(db, models, auth, { verbose: false })
    callRoute res, 'post', '/people', { }, ->
      expect(models.people.authCreate).calledWithExactly({ name: 'foobar' })
      done()

  it "for the POST-operation, falling back to write", (done) ->
    models = people: authWrite: sinon.mock().returns({})
    db = get: sinon.stub().yieldsAsync()
    auth = (req, callback) -> callback(null, { name: 'foobar' })

    res = generic.build(db, models, auth, { verbose: false })
    callRoute res, 'post', '/people', { }, ->
      expect(models.people.authWrite).calledWithExactly({ name: 'foobar' })
      done()

  it "for the POST-operation, falling back to read", (done) ->
    models = people: auth: sinon.mock().returns({})
    db = get: sinon.stub().yieldsAsync()
    auth = (req, callback) -> callback(null, { name: 'foobar' })

    res = generic.build(db, models, auth, { verbose: false })
    callRoute res, 'post', '/people', { }, ->
      expect(models.people.auth).calledWithExactly({ name: 'foobar' })
      done()

  it "for the POST-operation for a non-top level model", (done) ->
    models = {
      accounts: {}
      people: {
        owners: account: 'accounts'
        authCreate: sinon.mock().returns({})
      }
    }
    db = get: sinon.stub().yieldsAsync()
    auth = (req, callback) -> callback(null, { name: 'foobar' })

    res = generic.build(db, models, auth, { verbose: false })
    callRoute res, 'post', '/people', { }, ->
      expect(models.people.authCreate).calledWithExactly({ name: 'foobar' })
      done()

  it "for the POST-operation for a non-top level model, falling back to write", (done) ->
    models = {
      accounts: {}
      people: {
        owners: account: 'accounts'
        authWrite: sinon.mock().returns({})
      }
    }
    db = get: sinon.stub().yieldsAsync()
    auth = (req, callback) -> callback(null, { name: 'foobar' })

    res = generic.build(db, models, auth, { verbose: false })
    callRoute res, 'post', '/people', { }, ->
      expect(models.people.authWrite).calledWithExactly({ name: 'foobar' })
      done()

  it "for the POST-operation for a non-top level model, falling back to read", (done) ->
    models = {
      accounts: {}
      people: {
        owners: account: 'accounts'
        auth: sinon.mock().returns({})
      }
    }
    db = get: sinon.stub().yieldsAsync()
    auth = (req, callback) -> callback(null, { name: 'foobar' })

    res = generic.build(db, models, auth, { verbose: false })
    callRoute res, 'post', '/people', { }, ->
      expect(models.people.auth).calledWithExactly({ name: 'foobar' })
      done()

  it "for the POST-operation for a non-top level model, with an owner specified", (done) ->
    models = {
      accounts: {}
      people: {
        owners: account: 'accounts'
        authCreate: sinon.mock().returns({})
      }
    }
    db = get: sinon.stub().yieldsAsync()
    auth = (req, callback) -> callback(null, { name: 'foobar' })

    res = generic.build(db, models, auth, { verbose: false })
    callRoute res, 'post', '/accounts/:id/people', { }, ->
      expect(models.people.authCreate).calledWithExactly({ name: 'foobar' })
      done()

  it "for the POST-operation for a non-top level model, with an owner specified, falling back to write", (done) ->
    models = {
      accounts: {}
      people: {
        owners: account: 'accounts'
        authWrite: sinon.mock().returns({})
      }
    }
    db = get: sinon.stub().yieldsAsync()
    auth = (req, callback) -> callback(null, { name: 'foobar' })

    res = generic.build(db, models, auth, { verbose: false })
    callRoute res, 'post', '/accounts/:id/people', { }, ->
      expect(models.people.authWrite).calledWithExactly({ name: 'foobar' })
      done()

  it "for the POST-operation for a non-top level model, with an owner specified, falling back to read", (done) ->
    models = {
      accounts: {}
      people: {
        owners: account: 'accounts'
        auth: sinon.mock().returns({})
      }
    }
    db = get: sinon.stub().yieldsAsync()
    auth = (req, callback) -> callback(null, { name: 'foobar' })

    res = generic.build(db, models, auth, { verbose: false })
    callRoute res, 'post', '/accounts/:id/people', { }, ->
      expect(models.people.auth).calledWithExactly({ name: 'foobar' })
      done()

  it "for the POST-operation for a many-to-many, falling back to read", (done) ->
    models =
      people: {
        auth: sinon.mock().returns({})
        fields: {}
      }
      pets: {
        fields: {
          owners: {
            type: 'hasMany'
            model: 'people'
            inverseName: 'ownedPets'
          }
        }
      }
    db = get: sinon.stub().yieldsAsync()
    auth = (req, callback) -> callback(null, { name: 'foobar' })

    res = generic.build(db, models, auth, { verbose: false })
    callRoute res, 'post', '/people/:id/ownedPets/:other', { }, ->
      expect(models.people.auth).calledWithExactly({ name: 'foobar' })
      done()

  it "for the POST-operation for a many-to-many", (done) ->
    models =
      people: {
        fields: {}
        authWrite: sinon.mock().returns({})
      }
      pets: {
        fields: {
          owners: {
            type: 'hasMany'
            model: 'people'
            inverseName: 'ownedPets'
          }
        }
      }
    db = get: sinon.stub().yieldsAsync()
    auth = (req, callback) -> callback(null, { name: 'foobar' })

    res = generic.build(db, models, auth, { verbose: false })
    callRoute res, 'post', '/people/:id/ownedPets/:other', { }, ->
      expect(models.people.authWrite).calledWithExactly({ name: 'foobar' })
      done()

  it "for the POST-operation for a many-to-many inversed, falling back to read", (done) ->
    models =
      people: {
        fields: {}
      }
      pets: {
        auth: sinon.mock().returns({})
        fields: {
          owners: {
            type: 'hasMany'
            model: 'people'
            inverseName: 'ownedPets'
          }
        }
      }
    db = get: sinon.stub().yieldsAsync()
    auth = (req, callback) -> callback(null, { name: 'foobar' })

    res = generic.build(db, models, auth, { verbose: false })
    callRoute res, 'post', '/pets/:id/owners/:other', { }, ->
      expect(models.pets.auth).calledWithExactly({ name: 'foobar' })
      done()

  it "for the POST-operation for a many-to-many inversed", (done) ->
    models =
      people: {
        fields: {}
      }
      pets: {
        authWrite: sinon.mock().returns({})
        fields: {
          owners: {
            type: 'hasMany'
            model: 'people'
            inverseName: 'ownedPets'
          }
        }
      }
    db = get: sinon.stub().yieldsAsync()
    auth = (req, callback) -> callback(null, { name: 'foobar' })

    res = generic.build(db, models, auth, { verbose: false })
    callRoute res, 'post', '/pets/:id/owners/:other', { }, ->
      expect(models.pets.authWrite).calledWithExactly({ name: 'foobar' })
      done()

  it "for the DELETE-operation for a many-to-many, falling back to read", (done) ->
    models =
      people: {
        auth: sinon.mock().returns({})
        fields: {}
      }
      pets: {
        fields: {
          owners: {
            type: 'hasMany'
            model: 'people'
            inverseName: 'ownedPets'
          }
        }
      }
    db = get: sinon.stub().yieldsAsync()
    auth = (req, callback) -> callback(null, { name: 'foobar' })

    res = generic.build(db, models, auth, { verbose: false })
    callRoute res, 'del', '/people/:id/ownedPets/:other', { }, ->
      expect(models.people.auth).calledWithExactly({ name: 'foobar' })
      done()

  it "for the DELETE-operation for a many-to-many", (done) ->
    models =
      people: {
        fields: {}
        authWrite: sinon.mock().returns({})
      }
      pets: {
        fields: {
          owners: {
            type: 'hasMany'
            model: 'people'
            inverseName: 'ownedPets'
          }
        }
      }
    db = get: sinon.stub().yieldsAsync()
    auth = (req, callback) -> callback(null, { name: 'foobar' })

    res = generic.build(db, models, auth, { verbose: false })
    callRoute res, 'del', '/people/:id/ownedPets/:other', { }, ->
      expect(models.people.authWrite).calledWithExactly({ name: 'foobar' })
      done()

  it "for the DELETE-operation for a many-to-many inversed, falling back to read", (done) ->
    models =
      people: {
        fields: {}
      }
      pets: {
        auth: sinon.mock().returns({})
        fields: {
          owners: {
            type: 'hasMany'
            model: 'people'
            inverseName: 'ownedPets'
          }
        }
      }
    db = get: sinon.stub().yieldsAsync()
    auth = (req, callback) -> callback(null, { name: 'foobar' })

    res = generic.build(db, models, auth, { verbose: false })
    callRoute res, 'del', '/pets/:id/owners/:other', { }, ->
      expect(models.pets.auth).calledWithExactly({ name: 'foobar' })
      done()

  it "for the DELETE-operation for a many-to-many inversed", (done) ->
    models =
      people: {
        fields: {}
      }
      pets: {
        authWrite: sinon.mock().returns({})
        fields: {
          owners: {
            type: 'hasMany'
            model: 'people'
            inverseName: 'ownedPets'
          }
        }
      }
    db = get: sinon.stub().yieldsAsync()
    auth = (req, callback) -> callback(null, { name: 'foobar' })

    res = generic.build(db, models, auth, { verbose: false })
    callRoute res, 'del', '/pets/:id/owners/:other', { }, ->
      expect(models.pets.authWrite).calledWithExactly({ name: 'foobar' })
      done()

  it "for the GET-operation for a many-to-many", (done) ->
    models =
      people: {
        fields: {}
        auth: sinon.mock().returns({})
      }
      pets: {
        fields: {
          owners: {
            type: 'hasMany'
            model: 'people'
            inverseName: 'ownedPets'
          }
        }
      }
    db = get: sinon.stub().yieldsAsync()
    auth = (req, callback) -> callback(null, { name: 'foobar' })

    res = generic.build(db, models, auth, { verbose: false })
    callRoute res, 'get', '/people/:id/ownedPets', { }, ->
      expect(models.people.auth).calledWithExactly({ name: 'foobar' })
      done()

  it "for the GET-operation for a many-to-many inversed", (done) ->
    models =
      people: {
        fields: {}
      }
      pets: {
        auth: sinon.mock().returns({})
        fields: {
          owners: {
            type: 'hasMany'
            model: 'people'
            inverseName: 'ownedPets'
          }
        }
      }
    db = get: sinon.stub().yieldsAsync()
    auth = (req, callback) -> callback(null, { name: 'foobar' })

    res = generic.build(db, models, auth, { verbose: false })
    callRoute res, 'get', '/pets/:id/owners', { }, ->
      expect(models.pets.auth).calledWithExactly({ name: 'foobar' })
      done()
