ARG ALPINE_VERSION=3.19

FROM alpine:${ALPINE_VERSION} AS build

# installing using custom node package registry which may be password protected by itself
# version used (git/npm-repo) depends on dependencies declared inside package.json
#
# multi-stage build to not leak secret build-args
#
ARG NPM_CONFIG_REGISTRY
ARG NPM_CA_CERT
ARG NPM_SCOPE
ARG NPM_TOKEN
ARG NODE_EXTRA_CA_CERTS

# optional build arg to enable npm audit call, default runs check but does not exit on findings
ARG AUDIT_LEVEL="none"

WORKDIR /app
COPY . .

RUN apk update && apk upgrade \
    && apk add --no-cache nodejs curl jq ca-certificates sudo npm git \
    && echo -e "\n---- OS release ----------------------------------------------" \
    && cat /etc/os-release \
    && echo -e "\n---- Node / NPM versions -------------------------------------" \
    && node --version \
    && if [ $(which npm) ]; then npm --version; fi \
    && source /app/bin/configure-npm.sh \
    && echo -e "\n---- Check application config --------------------" \
    && for i in config/*.json; do echo "checking config $i"; jq empty < "$i"; ret=$?; if [ "$ret" -ne 0 ]; then exit "$ret"; fi; done \
    && echo -e "\n---- Install application -------------------------" \
    && npm install --no-audit --no-save \
    && echo -e "\n---- Run tests ------------------------------------------------" \
    && npm run test \
    && echo -e "\n---- Remove all dev packages (npm) ----------------------------" \
    && unset NPM_CONFIG_REGISTRY \
    && npm prune --production --no-audit \
    && echo -e "\n---- Security checks (without dev and against default registry) ---------------------------" \
    && rm -f ~/.npmrc \
    && npm audit --production "--audit-level=$AUDIT_LEVEL"


######
# Final image
######

FROM alpine:${ALPINE_VERSION}

LABEL maintainer="S. Seide <stefan@trilobyte-se.de>"
LABEL io.k8s.description="Small REST API server to bridge HTTP requests to Redis server for reading/writing data"
LABEL io.openshift.tags=dsa,redis,rest,converter
LABEL io.openshift.wants=redis

# optional build arg to let the hardening process remove the apk too to not allow installation
# of packages anymore, needed by some security check tools to query installed packages
# default: remove "apk"
ARG REMOVE_APK=1

ARG GIT_COMMIT_SHA=""
ENV GIT_SHA=$GIT_COMMIT_SHA

ARG SERVICE_USER="containerUser"
ENV SERVICE_USER=$SERVICE_USER

ARG TZ=Europe/Berlin
ENV TZ=$TZ

WORKDIR /app
COPY --from=build /app/node_modules /app/node_modules
COPY . .

RUN apk update && apk upgrade \
    && adduser -S "$SERVICE_USER" --uid 20000 -G root -h /app \
    && apk add --no-cache nodejs curl ca-certificates dumb-init tzdata\
    && echo -e "\n---- OS release ----------------------------------------------" \
    && cat /etc/os-release \
    && echo -e "\n---- Node / NPM versions -------------------------------------" \
    && node --version \
    && echo -e "\n---- Write git sha into version module -----------------------" \
    && echo "module.exports.gitSha = '$GIT_COMMIT_SHA';" > /app/gitVersion.js \
    && echo -e "\n---- Check file access rights ---------------" \
    && chown -R "${SERVICE_USER}.root" /app \
    && chmod g+w /app/config \
    && chmod 755 /app/*.sh /app/bin/*.sh \
    && echo -e "\n---- Cleanup and Hardening ------------------------------------" \
    && rm -rf /tmp/* /root/.??* /root/cache /var/cache/apk/* \
    && rm -rf /app/.??* /app/logs/* /app/.npmrc \
    && ln -s "/usr/share/zoneinfo/$TZ" /etc/localtime \
    && echo "$TZ" > /etc/timezone \
    && /app/bin/harden.sh

USER 20000

EXPOSE 4021

ENV NODE_ENV=production

ENTRYPOINT [ "/usr/bin/dumb-init", "--" ]
CMD ["/app/bin/docker-entrypoint.sh"]
