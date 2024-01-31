#!/bin/sh

# helper script to configure NPM registry used during docker build whenever packages from
# local/private registries are needed. Just add this script to the docker image and call
# it afterwards within the build process to not clutter regular Dockerfile too much.
#
# this script must be "source"d and not called! (due to env var exports herein)
#
# Author: S. Seide <stefan@trilobyte-se.de>
#
CUSTOM_CA_CERT_BASE_DIR=/bep

if [ ! "$(which npm)" ]; then
  echo 'npm not installed - skip configuration'
  exit 0
fi

# check if configured SERVICE_USER is a different user from the one this script is running with
if [ -n "${SERVICE_USER}" ] && [ "$(id -u)" != "$(id -u "${SERVICE_USER}")" ]; then
  echo 'current active user and SERVICE_USER differ - reconfigure npm for booth'
  CONFIG_SUDO=1
fi

#
# set http proxy if needed
#
npm config set proxy "${http_proxy:-}"
npm config set https-proxy "${https_proxy:-}"
npm config set noproxy "${no_proxy:-}"
[ "$CONFIG_SUDO" ] && sudo -u "${SERVICE_USER}" npm config set proxy "${http_proxy:-}"
[ "$CONFIG_SUDO" ] && sudo -u "${SERVICE_USER}" npm config set https-proxy "${https_proxy:-}"
[ "$CONFIG_SUDO" ] && sudo -u "${SERVICE_USER}" npm config set noproxy "${no_proxy:-}"

#
# now start configuration of npm...
#
if [ -n "$NODE_EXTRA_CA_CERTS" ]; then
    echo 'install custom ca certificate'
    export NODE_EXTRA_CA_CERTS="${CUSTOM_CA_CERT_BASE_DIR}/$NODE_EXTRA_CA_CERTS"
    cp "${CUSTOM_CA_CERT_BASE_DIR}/${NODE_EXTRA_CA_CERTS}" /usr/local/share/ca-certificates/
    update-ca-certificates
fi

if [ -n "$NPM_TOKEN" ]; then
    case "$NPM_TOKEN" in
        "NpmToken."*)
                CFG_KEY=_authToken
                ECHO_MSG="npm auth token for booth users (root and runtime user)"
                ;;
        *)
                CFG_KEY=_auth
                ECHO_MSG="npm auth credentials for booth users (root and runtime user)"
                ;;
    esac
    if [ -n "$NPM_CONFIG_REGISTRY" ]; then
        echo "add registry specific $ECHO_MSG"
        npm config set "//${NPM_CONFIG_REGISTRY#*//}:$CFG_KEY" "$NPM_TOKEN"
        [ "$CONFIG_SUDO" ] && sudo -u "${SERVICE_USER}" npm config set "//${NPM_CONFIG_REGISTRY#*//}:$CFG_KEY" "$NPM_TOKEN"
    else
        echo "add global $ECHO_MSG"
        npm config set $CFG_KEY "$NPM_TOKEN"
        [ "$CONFIG_SUDO" ] && sudo -u "${SERVICE_USER}" npm config set $CFG_KEY "$NPM_TOKEN"
    fi
fi

if [ -n "$NPM_CONFIG_REGISTRY" ]; then
    if [ -n "$NPM_SCOPE" ]; then
        echo "Custom scoped NPM registry set for $NPM_SCOPE: $NPM_CONFIG_REGISTRY"
        npm config set "${NPM_SCOPE}:registry" "$NPM_CONFIG_REGISTRY"
        [ "$CONFIG_SUDO" ] && sudo -u "${SERVICE_USER}" npm config set "${NPM_SCOPE}:registry" "$NPM_CONFIG_REGISTRY"
        # now remove env var to not let npm use it as default for everything
        unset NPM_CONFIG_REGISTRY
    else
        echo "Custom global NPM registry set: $NPM_CONFIG_REGISTRY"
    fi
fi

