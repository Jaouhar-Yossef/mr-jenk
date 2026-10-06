#!/bin/sh

set -e

docker run --rm \
    -v /home/yojaouhar/snap/code/264/.local/share/containers/storage/volumes/jenkins_home/_data/workspace/mr-jenk/frontend:/app \
    -w /app \
    node:22 \
    sh -c "npm ci && npm test -- --watch=false --reporters=junit --output-file=test-results.xml"