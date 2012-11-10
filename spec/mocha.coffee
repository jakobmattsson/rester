rester = require('./setup').requireSource('rester')
should = require 'should'
_ = require 'underscore'

it "should have the right methods", ->
  rester.should.have.keys [
    'exec'
    'verb'
    'respond'
  ]
