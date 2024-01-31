#!/usr/bin/env sh
# can be called from kubernetes lifecycle api after start of container before flagged as running
# called roughly in parallel to startup script
#
# use this script to send notifications etc. to external systems about starting up new pod now

# be posix compliant
HOSTNAME=${HOSTNAME:-$(uname -n)}

if [ -n "$SLACK_NOTIFY_URL" ]; then
    # shellcheck disable=SC2086
    curl -X POST -H 'Content-type: application/json' --data '{"text":"Start new pod: Redis-REST-Proxy / '$HOSTNAME'"}' "$SLACK_NOTIFY_URL"
fi

exit 0
