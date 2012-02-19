var http = require('http'); 

var block = function(f) {
  return f();
};

var jsonRequest = function(options, callback) {
  options.data     = options.data   || {};
  options.params   = options.params || {};
  options.headers  = options.headers || {};
  options.method   = options.method || 'GET';
  options.path     = options.path;
  options.host     = options.host;
  options.port     = options.port;

  var onceCallback = block(function() {
    var called = false;
    return function() {
      if (!called) {
        called = true;
        return callback.apply(this, arguments);
      }
    };
  });

  var headers = {};
  if (['GET', 'DELETE'].indexOf(options.method) === -1) {
    headers['Content-Type'] = 'application/json; charset=UTF-8';
  }

  var querystring = Object.keys(options.params).map(function(key) {
    return key + '=' + encodeURIComponent(options.params[key]);
  }).join('&');

  var req = http.request({
    host: options.host,
    port: options.port,
    path: options.path + (querystring ? '?' + querystring : ''),
    method: options.method,
    headers: headers
  }, function(res) {
    var body = "";
    res.setEncoding('utf8');
    res.on('data', function(chunk) {
      body += chunk;
    });
    res.on('end', function() {
      var error = null;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        error = res.statusCode;
        try {
          body = JSON.parse(body);
        } catch (e) {
          body = null;
        }
      } else {
        try {
          error = null;
          body = JSON.parse(body);
        } catch (e) {
          error = e;
          body = null;
        }
      }
      onceCallback(error, body, res.statusCode, res.headers);
    });
  });

  req.on('error', function(e) {
    onceCallback(e.message);
  });

  if (options.method != 'GET') {
    req.write(JSON.stringify(options.data));
  }

  req.end();
};

if (exports) {
  exports.jsonRequest = jsonRequest;
}