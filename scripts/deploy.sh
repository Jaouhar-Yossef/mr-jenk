#!/bin/sh

set -e

test -f "$ENV_FILE"

echo "Deploying version $APP_VERSION"

touch .deployment-attempted

docker compose \
    --env-file "$ENV_FILE" \
    -f compose.prod.yml \
    up -d

touch .deployment-successful

echo "Deployment completed: $APP_VERSION"