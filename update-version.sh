#!/bin/sh
#
# helper script to update all version numbers needed to create a new release
#   - package.json
#   - package-lock.json
#
# new version without leading "v" needed as version string (due to nodejs), e.g.
#   $ update-version.sh 1.2.3

NODEJS_DIR=.

# make sure tmp files can be created on all platforms including Windows
temporary_file() {
  TMP_CMD=$(which mktemp || which tempfile)
  if [ -n "$TMP_CMD" ]; then
    $TMP_CMD
  else
    # shellcheck disable=SC2039
    TMP_FILE="./tmp.$RANDOM.$$"
    touch $TMP_FILE || exit 1
    echo $TMP_FILE
  fi
}

check_jq() {
  if ! command -v jq > /dev/null; then
    echo 'ERROR - Please install "jq" command to parse/modify json files.'
    exit 1
  fi
}

check_current_version() {
	echo "Current versions:"
	echo "================="
  echo "package.json: $(jq -r '.version' "$NODEJS_DIR/package.json")"
  echo "package-lock: $(jq -r '.version' "$NODEJS_DIR/package-lock.json")"
}

update_version() {
  VERSION=$1
  # nodejs: update booth package.json and package-lock.json with new number
  cd "$NODEJS_DIR" || exit 1
  for i in package.json package-lock.json; do
    TMP=$(temporary_file)
    jq ".version=\"${VERSION}\"" "$i" > "$TMP" && mv "$TMP" "$i"
    # this is needed for v2 lock files, ignored on package.json and lock v1
    if [ "$(jq ".packages[\"\"].version" "$i")" != "null" ]; then
      jq ".packages[\"\"].version=\"${VERSION}\"" "$i" > "$TMP" && mv "$TMP" "$i"
    fi
  done
}


#
# start of main script
#
check_jq

# when script run from npm - working dir is same as package.json file
# change to project base dir then
WORK_DIR="$(dirname "$0")"
if [ "$WORK_DIR" != "." ] && [ "$WORK_DIR" != "" ]; then
  cd "$WORK_DIR" || exit 1
fi

# check needed parameter
if [ "$1" = "" ]; then
  echo "new version number needed as first parameter, e.g. '$0 0.1.2'"
  echo
  check_current_version
  exit 1
fi

update_version "$1"
