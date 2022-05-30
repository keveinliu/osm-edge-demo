#!/bin/bash

# shellcheck disable=SC1091
source .env

LOCAL_PORT="${LOCAL_PORT:-20001}"
POD="$(kubectl get pods --selector app=echo-http-server-v1 -n "$ECHO_HTTP_SERVER_NAMESPACE" --no-headers  | grep 'Running' | awk 'NR==1{print $1}')"

kubectl port-forward --address 0.0.0.0 "$POD" -n "$ECHO_HTTP_SERVER_NAMESPACE" "$LOCAL_PORT":20003
