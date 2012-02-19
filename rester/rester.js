var express = require("express");
var underscore = require('underscore');

var block = function(f) {
  return f();
};
var isUndefined = function(x) {
  return typeof x == "undefined";
};
var inString = function(x) {
  if (typeof x == "string") {
    return "'" + x + "'";
  }
  return x;
};



var rester = block(function() {
  return {
    service: function(spec, port, dbdriver) {

      var app = express.createServer();
      app.use(express.bodyParser());

      var rec = function(prepath, itemName, spec, itemsArray) {

        var properties = {};
        var subobjects = []

        Object.keys(spec).forEach(function(key) {
          if (typeof spec[key] == 'string') {
            properties[key] = spec[key];
          } else {
            subobjects.push(key);
            rec(prepath + '/:' + itemName + '/' + key, key, spec[key], itemsArray.concat(key));
          }
        });

        def('delete', prepath + '/:' + itemName, function(params, data, callback) {
          var items = itemsArray;
          var ps = items.map(function(name) { return params[name]; });
          dbdriver.deleteItem(items, ps, function(err, result) {
            // hanterar error här
            callback(null, result);
          });
        });
        def('put', prepath + '/:' + itemName, function(params, data, callback) {

          var newobj = { };
          var fails = [];

          Object.keys(properties).forEach(function(property) {
            if (!isUndefined(data[property])) {
              if (typeof data[property] == properties[property]) {
                newobj[property] = data[property];
              } else {
                fails.push('Invalid value of ' + inString(data[property]) + " for " + property + "; must be " + properties[property]);
              }
            }
          });

          if (fails.length > 0) {
            callback(fails.join('\n'));
          } else {
            var ps = itemsArray.map(function(name) { return params[name]; });
            
            dbdriver.updateItem(itemsArray, ps, newobj, function(err, newItem) {
              // hantera error här
              callback(null, newItem);
            });
          }
        });
        def('get', prepath + '/:' + itemName, function(params, data, callback) {
          var items = itemsArray;
          var ps = items.map(function(name) { return params[name]; });

          dbdriver.retrieveSingle(items, ps, function(err, data) {

            // hanterar error här
            callback(null, data);
          });
        });
        def('get', prepath, function(params, data, callback) {
          var items = itemsArray;
          var ps = items.map(function(name) { return params[name]; });

          dbdriver.retrieve(items, ps, function(err, data) {
            
            // hantera error här
            callback(null, data);
          });
        });
        def('post', prepath, function(params, data, callback) {

          var newobj = { };

          subobjects.forEach(function(subobject) {
            newobj[subobject] = {};
          });
          Object.keys(properties).forEach(function(property) {
            if (isUndefined(data[property])) {
              // sätt till annat default value om det finns i "properties"
              newobj[property] = null; 
            } else {
              // validera värdet här, om det finns någon validering inblandad
              newobj[property] = data[property];
            }
          });

          var items = itemsArray;
          var ps = items.map(function(name) { return params[name]; });

          dbdriver.save(items, ps, newobj, function(err) {
            // hantera error här
            delete newobj.apa;
            
            callback(null, newobj);
          });
        });
      };

      var def = function(method, path, callback) {
        app[method](path, function(req, res) {
          callback(req.params, req.body, function(err, data) {
            if (err) {
              res.send(JSON.stringify(err), { 'Content-Type': 'application/json' }, 400);
            } else {
              res.send(JSON.stringify(data), { 'Content-Type': 'application/json' }, 200);
            }
          });
        });
      };

      Object.keys(spec).forEach(function(key) {
        rec('/' + key, key, spec[key], [key]);
      });

      def('get', '/', function(params, data, callback) {
        dbdriver.serialize(function(err, db) {
          callback(err, db);
        });
      });

      def('delete', '/', function(params, data, callback) {
        dbdriver.clobber(spec, callback);
      });

      dbdriver.clobber(spec, function() {
        app.listen(port);
      });
    },
    prop: function(x) {
      return x;
    }
  };
});

var memdriver = block(function() {
  var db;
  var nextID = 1;

  var generateID = block(function() {
    return function() {
      nextID += 52;
      return nextID;
    };
  });

  var helper = function(collections, ids) {
    var collectionHeads = collections.slice(0, -1);
    var idsHeads = ids.slice(0, -1);

    var collectionLast = underscore(collections).last();
    var idLast = underscore(ids).last();

    var lastElement = underscore.zip(collectionHeads, idsHeads).reduce(function(memo, item) {
      return memo[item[0]][item[1]];
    }, db);
    
    return {
      element: lastElement,
      collection: collectionLast,
      id: idLast
    };
  };
  var lastCollection = function(collections, ids) {
    return underscore.zip(collections, ids).reduce(function(memo, item) {
      return memo[item[0]][item[1]];
    }, db);
  };

  return {
    clobber: function(spec, callback) {
      db = {};
      nextID = 1;
      Object.keys(spec).forEach(function(key) {
        db[key] = {};
      });
      callback(null);
    },
    save: function(collections, ids, newobj, callback) {
      var newid = generateID();
      var h = helper(collections, ids);
      h.element[h.collection][newid] = newobj;
      h.element[h.collection][newid].id = newid;
      callback(null);
    },
    retrieve: function(collections, ids, callback) {
      var h = helper(collections, ids);
      var res = h.element[h.collection];
      callback(null, res);
    },
    retrieveSingle: function(collections, ids, callback) {
      callback(null, lastCollection(collections, ids));
    },
    updateItem: function(collections, ids, newData, callback) {
      var e = lastCollection(collections, ids);
      Object.keys(newData).forEach(function(key) {
        e[key] = newData[key];
      });
      callback(null, e);
    },
    deleteItem: function(collections, ids, callback) {
      var h = helper(collections, ids);
      var deletedItem = h.element[h.collection][h.id];
      delete h.element[h.collection][h.id];
      callback(null, deletedItem);
    },
    serialize: function(callback) {
      callback(null, db);
    }
  };
});

exports.service = rester.service;
exports.prop = rester.prop;
exports.memdriver = memdriver;

