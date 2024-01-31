#!/usr/bin/env sh
# from: https://success.docker.com/article/use-a-script-to-initialize-stateful-container-data
# LINEENDING HAS TO BE UNIX, check with "cat -v docker-endpoint.sh"
set -e

# initialization
umask 027

# be posix compliant
HOSTNAME=${HOSTNAME:-$(uname -n)}

# set default value here for log messages
GIT_COMMIT_SHA=${GIT_COMMIT_SHA:-unset}

# when running in kubernetes we need to wait a bit before exiting on SIGTERM
# https://github.com/kubernetes/contrib/issues/1140#issuecomment-290836405
HANDLE_SIGTERM=${HANDLE_SIGTERM:-1}

# seconds to wait before sending sigquit to our app on exit
# only used if HANDLE_SIGTERM=1
GRACE_PERIOD=6

# default nodejs config setup to define json config files loaded
# see https://github.com/node-config/node-config/wiki/Environment-Variables
NODE_ENV=${NODE_ENV:-production}
NODE_APP_INSTANCE=${NODE_APP_INSTANCE:-docker}

# no env vars used here, only built-in
# busybox date from alpine does not now %N / %3N for nano seconds, hardcoded to 000 instead
printf '{"hostname":"%s","level":"info","event":"CONTAINER_START","module":"redis-rest-proxy","message":"starting node app Redis REST proxy","gitCommitSHA":"%s","intValue":%d,"timestamp":"%s"}\n' "$HOSTNAME" "$GIT_COMMIT_SHA" "$$" "$(date --utc +%Y-%m-%dT%T.000%Z)"


# install trap for SIGTERM to delay end of nginx a bit for kubernetes
# otherwise container might get requests after exiting itself
exitTrap() {
    sleep $GRACE_PERIOD
    kill -TERM "$NODE_PID"
}

if [ "$HANDLE_SIGTERM" = "1" ]; then
    trap exitTrap TERM INT
    setsid /usr/bin/node /app/app.js &
    NODE_PID=$!
    wait $NODE_PID
    trap - TERM INT
    wait $NODE_PID
    printf '{""hostname":"%s","level":"info","event":"CONTAINER_STOP","module":"redis-rest-proxy","message":"stop node app Redis REST proxy after SIGTERM","gitCommitSHA":"%s","intValue":%d,"timestamp":"%s"}\n' "$HOSTNAME" "$GIT_COMMIT_SHA" "$$" "$(date --utc +%Y-%m-%dT%T.999%Z)"
else
    exec /usr/bin/node /app/app.js
fi
