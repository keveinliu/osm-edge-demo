#!/bin/bash

set -aueo pipefail

# shellcheck disable=SC1091
source .env

./demo/deploy-echo-http-server.sh "v1"

./demo/deploy-echo-grpc-server.sh "v1"

./demo/deploy-echo-dubbo-server.sh "v1"

./demo/deploy-echo-http-consumer.sh "v1"

./demo/deploy-echo-grpc-consumer.sh "v1"

./demo/deploy-echo-dubbo-consumer.sh "v1"

./demo/deploy-ingress-pipy.sh