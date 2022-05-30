#!/bin/bash

# shellcheck disable=SC1091
source .env

POD="$(kubectl get pods --selector app=echo-grpc-server-v1 -n "$ECHO_GRPC_SERVER_NAMESPACE" --no-headers  | grep 'Running' | awk 'NR==1{print $1}')"

kubectl logs "${POD}" -n "$ECHO_GRPC_SERVER_NAMESPACE" -c echo-grpc-server-v1 --tail=100 -f
