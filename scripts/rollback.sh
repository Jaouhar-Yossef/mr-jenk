#!/bin/sh

set -e

if [ ! -f /var/jenkins_home/last-stable-version ]; then
    echo "No stable version available."
    exit 1
fi

STABLE_VERSION=$(cat /var/jenkins_home/last-stable-version)

if [ -z "$STABLE_VERSION" ]; then
    echo "Stable version is empty."
    exit 1
fi

echo "Rolling back from ${BUILD_NUMBER} to ${STABLE_VERSION}."

test -f "$ENV_FILE"

APP_VERSION="$STABLE_VERSION" \
docker compose \
    --env-file "$ENV_FILE" \
    -f compose.prod.yml \
    up -d \
    --force-recreate

echo "Rollback deployment completed: ${STABLE_VERSION}"