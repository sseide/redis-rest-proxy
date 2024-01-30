'use strict';
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


function RedisClient(options) {
  let opts = {};

  // only ioredis supported from now one ...
  // config options for ioredis (with sentinel support)
  if (options.sentinels && options.sentinelGroup) {
      opts.sentinels = this._parseRedisSentinel(options.sentinels);
      opts.name = options.sentinelGroup;
      if (options.has('sentinelPassword') && options.get('sentinelPassword')) {
          opts.sentinelPassword = options.get('sentinelPassword');
      }
      // only for logging:
      opts.url = 'sentinels://' + opts.name + JSON.stringify(opts.sentinels);
  }
  else {
      opts.port = (options.port ? options.port : 6379);
      opts.host = options.server;
      // only for logging:
      opts.url = 'ioredis://' + options.server + (options.port ? ':' + options.port : '');
  }
  opts.enableReadyCheck = true;
  opts.retryStrategy = this._redisRetryStrategy.bind(this);
  opts.reconnectOnError = this._redisRetryStrategy.bind(this);
  opts.keyPrefix = this.prefix;

  if (options.has('password') && options.get('password')) {
      opts.password = options.get('password');
  }
  if (options.has('database') && options.get('database')) {
      opts.db = options.get('database');
  }
  logger.debug('Create new Redis connection with url=%s, database=%s, password=%s',
      opts.url, opts.db, (opts.password ? '<set>' : '<empty>')
  );

  let Redis = require('ioredis');
  this.client = new Redis(opts);

  this.client.on('ready', (err) => {
      logger.debug('Redis client ready');
  });
  this.client.on('error', (err) => {
      logger.error('Redis client error: %s', err);
  });
}

RedisClient.prototype.getClient = function() {
  return this.client;
}

/**
 * Close the backend connection to the data store and invalidate this object.
 * After calling this function this object must be discarded and recreated with "new" if needed
 */
RedisClient.prototype.close = function() {
    clearInterval(this.pingTimer);
    if (this.client) {
        this.client.disconnect();
        this.client = null;
    }
    logger.info('Redis client closed');
};

/** Parse a string with redis sentinel names and ports to an objects as needed
 *  by ioredis for connections
 *
 *  @param {string} sentinelsString
 *  @return {object} ioredis sentinel list
 *  @private
 */
RedisClient.prototype._parseRedisSentinel = function(sentinelsString) {
    if (!sentinelsString || typeof sentinelsString !== 'string') return [];
    let sentinels = [];
    try {
        if (sentinelsString.startsWith('[')) {
            let obj = JSON.parse(sentinelsString);
            obj.forEach(function(sentinel) {
                if (typeof sentinel === 'object') sentinels.push(sentinel);
                else {
                    let tmp = sentinel.trim().split(':');
                    sentinels.push({host: tmp[0], port: tmp[1]});
                }
            });
        }
        else {
            // simple string, comma separated list of host:port
            let obj = sentinelsString.split(',');
            obj.forEach(function(sentinel) {
                if (sentinel && sentinel.trim()) {
                    let tmp = sentinel.trim().split(':');
                    sentinels.push({host: tmp[0], port: tmp[1]});
                }
            });
        }
    }
    catch (e) {
        this.logger.error('Cannot parse redis sentinels string');
    }
    return sentinels;
};

/** Method to control the reconnection behaviour of the redis client
 *
 *  @param {object} options values set from the redis client lib with data about the last connection lost
 *  @return {*} number of milliseconds when next connection attempt shall be started or non-number otherwise as exit-error
 *  @private
 */
RedisClient.prototype._redisRetryStrategy = function(options) {
  if (typeof options === 'number') {
    // ioredis simple reconnect
    // create options object from other vars...
    options = {
      error: 'unknown',
      attempt: options,
      total_retry_time: 1
    };
  }
};

module.exports.RedisClient = RedisClient;
