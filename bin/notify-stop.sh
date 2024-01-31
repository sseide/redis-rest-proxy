#!/usr/bin/env sh
# can be called from kubernetes lifecycle api before sending termination signal to container
# called synchronously before TERM sig
#
# use this script to send notifications etc. to external systems about going to stop running pod

# be posix compliant
HOSTNAME=${HOSTNAME:-$(uname -n)}

if [ -n "$SLACK_NOTIFY_URL" ]; then
    # shellcheck disable=SC2086
    curl -X POST -H 'Content-type: application/json' --data '{"text":"Going to stop pod: Redis-REST-Proxy / '$HOSTNAME'"}' "$SLACK_NOTIFY_URL"
fi

exit 0
