#!/bin/bash

# shellcheck disable=SC1091
source .env

kubectl describe pod "$(kubectl get pods -n "$ECHO_GRPC_SERVER_NAMESPACE" --show-labels --selector app=echo-grpc-server-v1 --no-headers | grep -v 'Terminating' | awk '{print $1}' | head -n1)" -n "$ECHO_CONSUMER_NAMESPACE"

POD="$(kubectl get pods --selector app=echo-grpc-server-v1 -n "$ECHO_GRPC_SERVER_NAMESPACE" --no-headers  | grep 'Running' | awk 'NR==1{print $1}')"

kubectl logs "${POD}" -n "$ECHO_GRPC_SERVER_NAMESPACE" -c sidecar --tail=100 -f
