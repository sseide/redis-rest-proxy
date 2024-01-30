const config = require('config');
const express = require('express');
const app = express();
const bodyParser = require('body-parser');

const port = Number.parseInt(config.get('server.port'));

const RedisClient = require('./lib/redisClient').RedisClient
const redisConnnections = {};

const logger = {
  debug: function(...args) {
    console.debug(args);
  },
  info: function(...args) {
    console.info(args);
  },
  warn: function(...args) {
    console.warn(args)
  },
  error: function(...args) {
    console.error(args)
  }
};

app.set('port', port);
app.disable('x-powered-by');
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({extended: false}));

app.get('/', (req, res) => {
  res.send('Hello World!')
});

app.post('/:connection/command', (req, res) => {
  const con = req.params.connection;
  if (con && config.has(`databases.${con}`)) {
    executeRedisCommand(con, req, res);
  }
  else {
    res.status(404).json({status: 'error', message: `database ${con} not configured` });
  }
});

app.post('/command', (req, res) => {
  try {
    executeRedisCommand(config.get('defaultDatabase'), req, res);
  }
  catch(e) {
    logger.error(e);
    res.status(404).json({status: 'error', message: `database ${config.get('defaultDatabase')} not configured` });
  }
});


const executeRedisCommand = async function(connection, req, res) {
  const cmd = req.body.cmd;
  let args = req.body.args;

  if (!cmd) {
    res.status(400).json({status: 'error', message: 'redis command "cmd" missing' });
    return;
  }
  try {
    const data = await getConnection(connection).call(cmd, args);
    res.json({status: 'success', data: data});
  }
  catch (err) {
    res.status(500).json({status: 'error', message: err.toString()});
  }
};

const getConnection = function(name){
  if (!redisConnnections.hasOwnProperty(name)) {
    redisConnnections[name] = new RedisClient(config.get(`databases.${name}`));
  }
  return redisConnnections[name].getClient();
}
/**
 * Start server
 * production server only listens to localhost, dev on all interfaces
 * production interface may be overwritten with Env-Var 'LISTEN_ADDRESS'
 */
let httpServer = null;
let logStartupFunc = null;
if (config.has('server.ssl.enabled') && config.get('server.ssl.enabled')) {
  const https = require('https');
  const fs = require('fs');
  const httpsOpt = {
    key: fs.readFileSync(__dirname + config.get('server.ssl.keyFile')),
    cert: fs.readFileSync(__dirname + config.get('server.ssl.certFile'))
  };
  logStartupFunc = function() {
    logger.info('running in %s with ssl on %j', app.get('env'), httpServer.address());
  };
  httpServer = https.createServer(httpsOpt, app);
}
else {
  // normal http needed
  httpServer = app;
  logStartupFunc = function() {
    logger.info('running in %s on %j', app.get('env'), httpServer.address());
  };
}

if (app.get('env') === 'production') {
  httpServer = httpServer.listen(app.get('port'), config.get('server.address'), logStartupFunc);
}
else {
  httpServer = httpServer.listen(app.get('port'), logStartupFunc);
}


// ===========================================
// exit handling for proper shutdown
// happens when you press Ctrl+C
process.on('SIGINT', function() {
  logger.warn('Gracefully shutting down from SIGINT (Crtl-C)');
  process.exit();
});
// SIGTERM usually called with kill
process.on('SIGTERM', function() {
  logger.warn('got SIGTERM - closing now');
  process.exit();
});
// Execute shutdown in clean exit - http server and database
process.on('exit', function() {
  // no more callbacks on process exit avail. close stuff fast!
  logger.info('Exiting HTTP server...');
  httpServer.close();
  _closeEverything();
});
httpServer.on('close', function() {
  // graceful shutdown of server - time to close db connection nicely
  logger.info('HTTP server closed...');
  _closeEverything();
});

const _closeEverything = function() {
  logger.info('Closing all data stores and connections...');
  Object.keys(redisConnnections).forEach((con) => {
    if (redisConnnections[con] && typeof redisConnnections[con].close === "function" ) {
      redisConnnections[con].close();
    }
  });
};
