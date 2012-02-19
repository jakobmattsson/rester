var express = require("express");
var underscore = require('underscore');
var rester = require("./rester/rester.js");
var p = rester.prop;

rester.service({
  tracks: {
    name: p('string'),
    people: {
      email: 'string',
      name: 'string',
      admin: 'bool',
      moods: {
        feeling: 'number'
      }
    }
  },
  zero: {
    one: {
      two: {
        three: {
          text: 'string'
        }
      }
    }
  }
}, 3000, rester.memdriver);
