# HTTP to Redis Proxy

## WORK-IN-PROGRESS

Small proxy application to convert HTTP requests onto Redis commands for configured backend Redis servers.
All Redis server must be preconfigured to allow access via HTTP.

Publish/Subscribe and similar mechanisms are not supported, only single requests with one-time answers
are implemented right now. Similar the "select" command to switch databases is not supported.

Multiple Redis backends can be configured for parallel access.

## Configuration

Configuration is done via JSON config files located inside the "config/" subdirectory using the
NodeJS ("config" module)[https://github.com/node-config/node-config].

