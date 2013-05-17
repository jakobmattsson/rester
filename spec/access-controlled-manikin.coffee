jscov = require 'jscov'
sinon = require 'sinon'
chai = require 'chai'
sinonChai = require 'sinon-chai'

chai.use sinonChai
expect = chai.expect

acm = require jscov.cover('..', 'lib', 'access-controlled-manikin')

noErr = (f) -> (err, rest...) ->
  if err
    console.log "WHAAAAAT"
    console.log err
  expect(err?).to.eql false
  f(rest...)


['AuthError', 'ClientError'].forEach (error) ->

  describe error, ->

    it "is an error", ->
      expect(new acm[error]()).to.be.an.instanceof Error

    it "propagates the error message", ->
      expect(new acm[error]('hello').message).to.eql 'hello'



describe 'internal helper', ->

  describe 'joinFilters', ->

    it 'joins an empty list of arguments', ->
      expect(acm.joinFilters()).to.eql {}

    it 'joins an single argument', ->
      expect(acm.joinFilters({ a: 1, b: 2 })).to.eql { a: 1, b: 2 }

    it 'joins a null argument with a proper argument', ->
      expect(acm.joinFilters({ a: 1, b: 2 }, null)).to.eql { a: 1, b: 2 }

    it 'joins a single null argument', ->
      expect(acm.joinFilters(null)).to.eql {}

    it 'joins two different objects', ->
      expect(acm.joinFilters({ a: 1, b: 2 }, { c: 3 })).to.eql { a: 1, b: 2, c: 3 }

    it 'joins two objects with an overlapping key-value-pair', ->
      expect(acm.joinFilters({ a: 1, b: 2 }, { b: 2, c: 3 })).to.eql { a: 1, b: 2, c: 3 }

    it 'joins two objects with an overlapping key, but different values', ->
      expect(acm.joinFilters({ a: 1, b: 2 }, { b: 20, c: 3 })).to.eql undefined

    it 'joins three objects, where a single one contains a different value', ->
      expect(acm.joinFilters({ a: 1, b: 2 }, { b: 5 }, { b: 2, c: 3 })).to.eql undefined

    it 'joins three objects, with no completely common keys, but one overlapping with invalid value', ->
      expect(acm.joinFilters({ a: 1, b: 2 }, { b: 2, c: 3 }, { c: 5 })).to.eql undefined

    it 'joins three objects, where a single one is missing the otherwise overlapping values', ->
      expect(acm.joinFilters({ a: 1, b: 2 }, { b: 2, c: 3 }, { d: 5 })).to.eql { a: 1, b: 2, c: 3, d: 5 }



describe 'the list-operation', ->

  it "invokes correctly given an overlapping auth object and filter", (done) ->
    models = people: auth: -> { lastName: 'doe' }
    db = list: sinon.mock().yieldsAsync()
    res = acm.build(db, models, {})

    res.list 'people', { lastName: 'doe' }, noErr (data) ->
      expect(db.list).calledWith('people', { lastName: 'doe' })
      done()

  it "invokes incorrectly given overlapping auth object and filter, with different values", (done) ->
    models = people: auth: -> { lastName: 'smith' }
    db = list: sinon.mock().yieldsAsync()
    res = acm.build(db, models, {})

    res.list 'people', { lastName: 'doe' }, (err, data) ->
      expect(db.list).notCalled
      expect(err.message).to.eql 'unauthed'
      done()




describe 'the list-operation', ->

  it "invokes correctly when there is no auth-restriction", (done) ->
    models = people: {}
    result = Math.random()
    db = { list: sinon.mock().yieldsAsync(undefined, result) }
    res = acm.build(db, models, {})

    res.list 'people', { }, noErr (data) ->
      expect(db.list).calledWith('people', { })
      expect(data).to.eql result
      done()



  it "invokes correctly when the user is partially authorized", (done) ->
    models = people: auth: -> { x: 1 }
    result = Math.random()
    db = { list: sinon.mock().yieldsAsync(null, result) }
    res = acm.build(db, models, null)
    res.list 'people', null, noErr (data) ->
      expect(db.list).calledWith('people', { x: 1 })
      expect(data).to.eql result
      done()



  it "invokes correctly when the user is not authorized", (done) ->
    models = people: auth: -> null
    res = acm.build({}, models, null)
    res.list 'people', {}, (err, data) ->
      expect(err.message).to.eql 'unauthed'
      expect(data).to.eql undefined
      done()



describe 'the get-operation', ->

  it "invokes correctly when there is no auth-restriction", (done) ->
    models = { people: {} }
    result = Math.random()
    db = { getOne: sinon.mock().yieldsAsync(null, { res: result }) }
    res = acm.build(db, models, null)

    res.getOne 'people', { filter: { id: 123 } }, noErr (data) ->
      expect(db.getOne).calledWith('people', { filter: { id: 123 } })
      expect(data).to.eql { res: result }
      done()



  it "invokes correctly when the user is partially authorized", (done) ->
    result = Math.random()
    models = people: auth: -> { x: 1 }
    db = { getOne: sinon.mock().yieldsAsync(null, { res: result }) }

    res = acm.build(db, models, null)
    res.getOne 'people', { filter: { id: 456 } }, noErr (data) ->
      expect(db.getOne).calledWith('people', { filter: { x: 1, id: 456 } })
      expect(data).to.eql { res: result }
      done()



  it "invokes correctly when the user is not authorized", (done) ->
    models = people: auth: -> null
    auth = sinon.stub().yieldsAsync()
    res = acm.build({}, models, null)
    res.getOne 'people', { filter: { id: 789 } }, (err, data) ->
      expect(err.message).to.eql 'unauthed'
      expect(data).to.eql undefined
      done()




describe 'the put-operation', ->

  it "invokes correctly when there is no auth-restriction", (done) ->
    models = people: {}
    result = Math.random()
    db = { putOne: sinon.mock().yieldsAsync(null, { r: result }) }
    res = acm.build(db, models, null)

    res.putOne 'people', { v1: 100, v2: 200 }, { id: 123 }, noErr (data) ->
      expect(db.putOne).calledWith('people', { v1: 100, v2: 200 }, { id: 123 })
      expect(data).to.eql { r: result }
      done()



  it "invokes correctly when the user is partially authorized", (done) ->
    models = people: auth: -> { x: 1 }
    result = Math.random()
    db = { putOne: sinon.mock().yieldsAsync(undefined, { result }) }
    res = acm.build(db, models, null)
    res.putOne 'people', { v1: 100, v2: 200 }, { id: 456 }, noErr (data) ->
      expect(db.putOne).calledWith('people', { v1: 100, v2: 200 }, { x: 1, id: 456 })
      expect(data).to.eql { result: result }
      done()



  it "invokes correctly when the user is not authorized", (done) ->
    models = people: auth: -> null
    res = acm.build({}, models, null)
    res.putOne 'people', { v1: 100, v2: 200 }, { id: 789 }, (err, data) ->
      expect(err.message).to.eql 'unauthed'
      expect(data).to.eql undefined
      done()






describe 'the del-operation', ->

  it "invokes correctly when there is no auth-restriction", (done) ->
    models = people: {}
    result = Math.random()
    db = { delOne: sinon.mock().yieldsAsync(null, { res: result }) }
    res = acm.build(db, models, null)
    res.delOne 'people', { id: 123 }, noErr (data) ->
      expect(db.delOne).calledWith('people', { id: 123 })
      expect(data).to.eql { res: result }
      done()



  it "invokes correctly when the user is partially authorized", (done) ->
    models = people: auth: -> { x: 1 }
    result = Math.random()
    db = { delOne: sinon.mock().yieldsAsync(null, { res: result }) }
    res = acm.build(db, models, null)
    res.delOne 'people', { id: 456 }, noErr (data) ->
      expect(db.delOne).calledWith('people', { x: 1, id: 456 })
      expect(data).to.eql { res: result }
      done()



  it "invokes correctly when the user is not authorized", (done) ->
    models = people: auth: -> null
    auth = sinon.stub().yieldsAsync()
    res = acm.build({}, models, null)
    res.delOne 'people', { id: 789 }, (err, data) ->
      expect(err.message).to.eql 'unauthed'
      expect(data).to.eql undefined
      done()








describe "the auth-function of the model gets passed the result of the getUser function", ->

  it "for the LIST-operation", (done) ->
    models = people: auth: sinon.mock().returns({})
    db = list: sinon.stub().yieldsAsync()

    res = acm.build(db, models, { name: 'foobar' })
    res.list 'people', {}, noErr ->
      expect(models.people.auth).calledWithExactly({ name: 'foobar' })
      done()

  it "for the GET-operation", (done) ->
    models = people: auth: sinon.mock().returns({})
    db = getOne: sinon.stub().yieldsAsync()

    res = acm.build(db, models, { name: 'foobar' })
    res.getOne 'people', { }, noErr ->
      expect(models.people.auth).calledWithExactly({ name: 'foobar' })
      done()

  it "for the DELETE-operation", (done) ->
    models = people: authWrite: sinon.mock().returns({})
    db = delOne: sinon.stub().yieldsAsync()

    res = acm.build(db, models, { name: 'foobar' })
    res.delOne 'people', { }, noErr ->
      expect(models.people.authWrite).calledWithExactly({ name: 'foobar' })
      done()

  it "for the DELETE-operation, falling back to the read-auth function", (done) ->
    models = people: auth: sinon.mock().returns({})
    db = delOne: sinon.stub().yieldsAsync()

    res = acm.build(db, models, { name: 'foobar' })
    res.delOne 'people', { }, noErr ->
      expect(models.people.auth).calledWithExactly({ name: 'foobar' })
      done()

  it "for the POST-operation", (done) ->
    models = people: authCreate: sinon.mock().returns({})
    db = post: sinon.stub().yieldsAsync()

    res = acm.build(db, models, { name: 'foobar' })
    res.post 'people', { }, noErr ->
      expect(models.people.authCreate).calledWithExactly({ name: 'foobar' })
      done()

  it "for the POST-operation, falling back to write", (done) ->
    models = people: authWrite: sinon.mock().returns({})
    db = post: sinon.stub().yieldsAsync()

    res = acm.build(db, models, { name: 'foobar' })
    res.post 'people', { }, noErr ->
      expect(models.people.authWrite).calledWithExactly({ name: 'foobar' })
      done()

  it "for the POST-operation, falling back to read", (done) ->
    models = people: auth: sinon.mock().returns({})
    db = post: sinon.stub().yieldsAsync()

    res = acm.build(db, models, { name: 'foobar' })
    res.post 'people', { }, noErr ->
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
    db = post: sinon.stub().yieldsAsync()

    res = acm.build(db, models, { name: 'foobar' })
    res.post 'people', { }, noErr ->
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
    db = post: sinon.stub().yieldsAsync()

    res = acm.build(db, models, { name: 'foobar' })
    res.post 'people', { }, noErr ->
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
    db = post: sinon.stub().yieldsAsync()

    res = acm.build(db, models, { name: 'foobar' })
    res.post 'people', { }, noErr ->
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
    db = post: sinon.stub().yieldsAsync()

    res = acm.build(db, models, { name: 'foobar' })
    res.post 'people', { }, noErr ->
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
    db = post: sinon.stub().yieldsAsync()

    res = acm.build(db, models, { name: 'foobar' })
    res.post 'people', { }, noErr ->
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
    db = post: sinon.stub().yieldsAsync()

    res = acm.build(db, models, { name: 'foobar' })
    res.post 'people', { }, noErr ->
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
    db = {
      getOne: sinon.stub().yieldsAsync()
      postMany: sinon.stub().yieldsAsync()
    }

    res = acm.build(db, models, { name: 'foobar' })
    res.postMany 'people', 123, 'ownedPets', { }, noErr ->
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
    db = {
      getOne: sinon.stub().yieldsAsync()
      postMany: sinon.stub().yieldsAsync()
    }

    res = acm.build(db, models, { name: 'foobara' })
    res.postMany 'people', {}, 'ownedPets', { }, noErr ->
      expect(models.people.authWrite).calledWithExactly({ name: 'foobara' })
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
    db = {
      getOne: sinon.stub().yieldsAsync()
      postMany: sinon.stub().yieldsAsync()
    }

    res = acm.build(db, models, { name: 'foobar' })
    res.postMany 'pets', '123', 'owners', { }, noErr ->
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
    db = {
      getOne: sinon.stub().yieldsAsync()
      postMany: sinon.stub().yieldsAsync()
    }

    res = acm.build(db, models, { name: 'foobar' })
    res.postMany 'pets', ':id', 'owners', { }, noErr ->
      expect(models.pets.authWrite).calledWithExactly({ name: 'foobar' })
      done()

  it "for the DELETE-operation for a many-to-many, falling back to read", (done) ->
    models =
      people: {
        auth: sinon.stub().returns({})
        fields: {}
      }
      pets: {
        auth: sinon.stub().returns({})
        fields: {
          owners: {
            type: 'hasMany'
            model: 'people'
            inverseName: 'ownedPets'
          }
        }
      }

    db = {
      getOne: sinon.stub().yieldsAsync()
      delMany: sinon.stub().yieldsAsync()
    }

    res = acm.build(db, models, { name: 'foobar' })
    res.delMany 'people', 'id', 'ownedPets', { }, noErr ->
      expect(models.pets.auth).calledWithExactly({ name: 'foobar' })
      expect(models.people.auth).calledWithExactly({ name: 'foobar' })
      done()

  it "for the DELETE-operation for a many-to-many", (done) ->
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
    db = {
      getOne: sinon.stub().yieldsAsync()
      delMany: sinon.stub().yieldsAsync()
    }

    res = acm.build(db, models, { name: 'foobar' })
    res.delMany 'people', ':id', 'ownedPets', { }, noErr ->
      expect(models.pets.authWrite).calledWithExactly({ name: 'foobar' })
      done()

  it "for the DELETE-operation for a many-to-many inversed, falling back to read", (done) ->
    models =
      people: {
        auth: sinon.stub().returns({})
        fields: {}
      }
      pets: {
        auth: sinon.stub().returns({})
        fields: {
          owners: {
            type: 'hasMany'
            model: 'people'
            inverseName: 'ownedPets'
          }
        }
      }
    db = {
      getOne: sinon.stub().yieldsAsync()
      delMany: sinon.stub().yieldsAsync()
    }

    res = acm.build(db, models, { name: 'foobar' })
    res.delMany 'pets', '/:id', 'owners', { }, noErr ->
      expect(models.people.auth).calledWithExactly({ name: 'foobar' })
      expect(models.pets.auth).calledWithExactly({ name: 'foobar' })
      done()

  it "for the DELETE-operation for a many-to-many inversed", (done) ->
    models =
      people: {
        authWrite: sinon.mock().returns({})
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
    db = {
      getOne: sinon.stub().yieldsAsync()
      delMany: sinon.stub().yieldsAsync()
    }

    res = acm.build(db, models, { name: 'foobar' })
    res.delMany 'pets', '/:id', 'owners', { }, noErr ->
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
    db = {
      getOne: sinon.stub().yieldsAsync()
      getMany: sinon.stub().yieldsAsync()
    }

    res = acm.build(db, models, { name: 'foobar' })
    res.getMany 'people', '/:id', 'ownedPets', { }, noErr ->
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
    db = {
      getOne: sinon.stub().yieldsAsync()
      getMany: sinon.stub().yieldsAsync()
    }

    res = acm.build(db, models, { name: 'foorbar' })
    res.getMany 'pets', '/:id', 'owners', { }, noErr ->
      expect(models.pets.auth).calledWithExactly({ name: 'foorbar' })
      done()
