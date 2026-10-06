#!/bin/sh

set -e

test -f "$ENV_FILE"

echo "Checking rollback health..."

for i in $(seq 1 30); do

    DISCOVERY_STATUS=$(docker inspect \
        --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' \
        discovery-server)

    GATEWAY_STATUS=$(docker inspect \
        --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' \
        api-gateway)

    MONGO_STATUS=$(docker inspect \
        --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' \
        mongodb)

    if [ "$DISCOVERY_STATUS" = "healthy" ] \
        && [ "$GATEWAY_STATUS" = "healthy" ] \
        && [ "$MONGO_STATUS" = "healthy" ]; then

        echo "Rollback health check passed."
        exit 0
    fi

    echo "Rollback health check $i/30: Discovery=$DISCOVERY_STATUS Gateway=$GATEWAY_STATUS MongoDB=$MONGO_STATUS"

    sleep 5
done

echo "Rollback health check failed."

docker compose \
    --env-file "$ENV_FILE" \
    -f compose.prod.yml \
    ps

exit 1