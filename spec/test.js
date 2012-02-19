var api = require("../request/request.js");
var assert = require('assert');
var async = require('async');

var req = function(path, method, data, callback) {
  api.jsonRequest({
    path: path,
    host: 'localhost',
    port: 3000,
    method: method,
    data: data,
    params: { },
  }, callback);
};

var argslogger = function() {
  console.log(arguments);
};

Object.prototype.without = function() {
  var args = Array.prototype.slice.call(arguments, 0);
  var self = this;

  return Object.keys(self).filter(function(e) {
    return args.indexOf(e) === -1;
  }).reduce(function(memo, key) {
    memo[key] = self[key];
    return memo;
  }, {});
};


var get = function(path, callback) {
  req(path, 'GET', null, callback || argslogger);
};
var put = function(path, data, callback) {
  req(path, 'PUT', data, callback || argslogger);
};
var post = function(path, data, callback) {
  req(path, 'POST', data, callback || argslogger);
};
var del = function(path, callback) {
  req(path, 'DELETE', null, callback || argslogger);
};



async.waterfall([
  function(callback) {
    del('/', function(err, data) {
      console.log("step 1", data);
      assert.deepEqual(data, null);
      callback();
    });
  },
  function(callback) {
    get('/', function(err, data) {
      console.log("step 2", data);
      assert.deepEqual(data, { tracks: {}, zero: {} });
      callback();
    });
  },
  function(callback) {
    post('/tracks', { name: 'track 1', unused: 1 }, function(err, data) {
      console.log("step 3", data);
      assert.deepEqual(data.without('id'), { name: 'track 1', people: {} });
      callback();
    });
  },
  function(callback) {
    get('/', function(err, data) {
      console.log("step 4", data);
      assert.deepEqual(data, { zero: {}, tracks: { '53': { name: 'track 1', id: 53, people: {} }}});
      callback();
    });
  },
  function(callback) {
    post('/tracks/53/people', { name: 'Jakob' }, function(err, data) {
      console.log("step 5", data);
      assert.deepEqual(data.without('id'), { name: 'Jakob', email: null, admin: null, moods: {} });
      callback();
    });
  },
  function(callback) {
    get('/', function(err, data) {
      console.log("step 6", data);
      assert.deepEqual(data, { zero: {}, tracks: { '53': { name: 'track 1', id: 53, people: {
        '105': { name: 'Jakob', email: null, admin: null, moods: {}, id: 105 }
      } }}});
      callback();
    });
  },
  function(callback) {
    get('/tracks/53/people', function(err, data) {
      console.log("step 7", data);
      assert.deepEqual(data, { '105': { name: 'Jakob', email: null, admin: null, moods: {}, id: 105 }});
      callback();
    });
  },
  function(callback) {
    get('/tracks/53', function(err, data) {
      console.log("step 8", data);
      assert.deepEqual(data, { name: 'track 1', id: 53, people: { '105': { name: 'Jakob', email: null, admin: null, moods: {}, id: 105 }}});
      callback();
    });
  },
  function(callback) {
    post('/tracks/53/people', { email: '2' }, function(err, data) {
      console.log("step 9", data);
      assert.deepEqual(data.without('id'), { name: null, email: '2', admin: null, moods: {} });
      callback();
    });
  },
  function(callback) {
    get('/tracks/53', function(err, data) {
      console.log("step 10", data);
      assert.deepEqual(data, { name: 'track 1', id: 53, people: { 
        '105': { name: 'Jakob', email: null, admin: null, moods: {}, id: 105 },
        '157': { name: null, email: '2', admin: null, moods: {}, id: 157 }
      }});
      callback();
    });
  },
  function(callback) {
    put('/tracks/53/people/105', { email: 'epost' }, function(err, data) {
      console.log("step 11", data);
      assert.deepEqual(data, { name: 'Jakob', email: 'epost', admin: null, moods: {}, id: 105 });
      callback();
    });
  },
  function(callback) {
    put('/tracks/53/people/105', { name: 123 }, function(err, data) {
      assert.deepEqual(err, 400);
      assert.deepEqual(data, "Invalid value of 123 for name; must be string");
      callback();
    });
  },
  function(callback) {
    put('/tracks/53/people/105', { admin: 'test' }, function(err, data) {
      assert.deepEqual(err, 400);
      assert.deepEqual(data, "Invalid value of 'test' for admin; must be bool");
      callback();
    });
  },
  function(callback) {
    del('/tracks/53/people/157', function(err, data) {
      console.log("step 12", data);
      assert.deepEqual(data, { name: null, email: '2', admin: null, moods: {}, id: 157 });
      callback();
    });
  },
  function(callback) {
    get('/tracks/53', function(err, data) {
      console.log("step 13", data);
      assert.deepEqual(data, { name: 'track 1', id: 53, people: { 
        '105': { name: 'Jakob', email: 'epost', admin: null, moods: {}, id: 105 }
      }});
      callback();
    });
  },
]);
