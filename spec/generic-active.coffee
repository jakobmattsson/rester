jscov = require 'jscov'
generic = require jscov.cover('..', 'lib', 'generic')
should = require 'should'
express = require 'express'
manikin = require 'manikin-mongodb' # använd memory-varianten istället för att köra tester
mongojs = require 'mongojs'
_ = require 'underscore'
sinon = require 'sinon'
chai = require 'chai'
sinonChai = require 'sinon-chai'

chai.use sinonChai
expect = chai.expect



callRoute = (res, met, rot, req, callback) ->
  matches = res.routes.filter(({ method, route }) -> method == met && route == rot)
  matches.length.should.eql 1
  matches[0].callback(req, callback)


describe 'build', ->

  it "invokes the list-operation correctly when there is no auth-restriction", (done) ->
    models = { people: {} }
    db = { list: sinon.mock().yieldsAsync() }
    auth = sinon.stub().yieldsAsync()
    res = generic.build(db, models, auth, { verbose: false })

    callRoute res, 'get', '/people', { }, ->
      expect(db.list).calledWith('people', { })
      done()



  it "invokes the list-operation correctly when the user is partially authorized", (done) ->
    models =
      people:
        auth: -> { x: 1 }

    user = { name: 'jakob' }
    db = { list: sinon.mock().yieldsAsync() }
    auth = sinon.stub().yieldsAsync()
    res = generic.build(db, models, auth, { verbose: false })
    callRoute res, 'get', '/people', {}, ->
      expect(db.list).calledWith('people', { x: 1 })
      done()



  it "invokes the list-operation correctly when the user is not authorized", (done) ->
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
