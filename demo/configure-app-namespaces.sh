#!/bin/bash

set -aueo pipefail

# shellcheck disable=SC1091
source .env

for ns in "$ECHO_CONSUMER_NAMESPACE" "$ECHO_DUBBO_SERVER_NAMESPACE" "$ECHO_GRPC_SERVER_NAMESPACE" "$ECHO_HTTP_SERVER_NAMESPACE"; do
    kubectl create namespace "$ns" --save-config
    ./scripts/create-container-registry-creds.sh "$ns"
done

# Add namespaces to the mesh
osm namespace add --mesh-name "$MESH_NAME" "$ECHO_CONSUMER_NAMESPACE" "$ECHO_DUBBO_SERVER_NAMESPACE" "$ECHO_GRPC_SERVER_NAMESPACE" "$ECHO_HTTP_SERVER_NAMESPACE"

# Enable metrics for pods belonging to app namespaces
osm metrics enable --namespace "$ECHO_CONSUMER_NAMESPACE, $ECHO_DUBBO_SERVER_NAMESPACE, $ECHO_GRPC_SERVER_NAMESPACE, $ECHO_HTTP_SERVER_NAMESPACE"
