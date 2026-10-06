#!/bin/sh

set -e

test -f "$KEYSTORE_FILE"
test -f "$ENV_FILE"

install -D "$KEYSTORE_FILE" \
    api-gateway/src/main/resources/keystore.p12

trap 'rm -f api-gateway/src/main/resources/keystore.p12' EXIT

echo "Building Docker images: $APP_VERSION"

docker compose \
    --env-file "$ENV_FILE" \
    -f compose.prod.yml \
    build