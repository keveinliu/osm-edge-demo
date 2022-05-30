#!/bin/bash

# shellcheck disable=SC1091
source .env

POD="$(kubectl get pods --selector app=echo-http-server-v1 -n "$ECHO_HTTP_SERVER_NAMESPACE" --no-headers  | grep 'Running' | awk 'NR==1{print $1}')"

kubectl logs "${POD}" -n "$ECHO_HTTP_SERVER_NAMESPACE" -c echo-http-server-v1 --tail=100 -f
