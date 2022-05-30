#!/bin/bash


# This script port forwards from the BOOKBUYER pod to local port 8080


# shellcheck disable=SC1091
source .env

LOCAL_PORT="${LOCAL_PORT:-8090}"
POD="$(kubectl get pods --selector app=echo-consumer-v1 -n "$ECHO_CONSUMER_NAMESPACE" --no-headers  | grep 'Running' | awk 'NR==1{print $1}')"

kubectl port-forward --address 0.0.0.0 "$POD" -n "$ECHO_CONSUMER_NAMESPACE" "$LOCAL_PORT":8090
