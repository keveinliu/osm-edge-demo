#!/bin/bash

set -aueo pipefail

# shellcheck disable=SC1091
source .env
VERSION=${1:-v1}
SVC="echo-grpc-consumer-$VERSION"
USE_PRIVATE_REGISTRY="${USE_PRIVATE_REGISTRY:-true}"
KUBE_CONTEXT=$(kubectl config current-context)
ENABLE_MULTICLUSTER="${ENABLE_MULTICLUSTER:-false}"
KUBERNETES_NODE_ARCH="${KUBERNETES_NODE_ARCH:-amd64}"
KUBERNETES_NODE_OS="${KUBERNETES_NODE_OS:-linux}"

kubectl delete deployment "$SVC" -n "$ECHO_CONSUMER_NAMESPACE"  --ignore-not-found

echo -e "Deploy $SVC Service Account"
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: "$SVC"
  namespace: $ECHO_CONSUMER_NAMESPACE
EOF

echo -e "Deploy $SVC Service"
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: $SVC
  namespace: $ECHO_CONSUMER_NAMESPACE
  labels:
    app: echo-grpc-consumer
spec:
  ports:
  - port: 8090
    name: http
    appProtocol: tcp
  - port: 8080
    name: tcp
    appProtocol: tcp
  selector:
    app: $SVC
EOF

echo -e "Deploy $SVC Deployment"
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $SVC
  namespace: $ECHO_CONSUMER_NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $SVC
      version: $VERSION
  template:
    metadata:
      labels:
        app: $SVC
        version: $VERSION
    spec:
      serviceAccountName: "$SVC"
      nodeSelector:
        kubernetes.io/arch: ${KUBERNETES_NODE_ARCH}
        kubernetes.io/os: ${KUBERNETES_NODE_OS}
      containers:
        - image: "${CTR_REGISTRY}/osm-edge-demo-echo-grpc-consumer:${CTR_TAG}"
          imagePullPolicy: Always
          name: $SVC
          ports:
            - name: http
              containerPort: 8090
              protocol: TCP
            - containerPort: 8080
              protocol: TCP
          command: ["/echo-grpc-consumer"]
          args: ["--grpc-server=echo-grpc-server-v1.echo-grpc-server.svc.cluster.local:20001"]
          env:
            - name: IDENTITY
              value: ${SVC}.${KUBE_CONTEXT}
            - name: GIN_MODE
              value: debug
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  apiVersion: v1
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  apiVersion: v1
                  fieldPath: metadata.namespace
            - name: POD_IP
              valueFrom:
                fieldRef:
                  apiVersion: v1
                  fieldPath: status.podIP
            - name: SERVICE_ACCOUNT
              valueFrom:
                fieldRef:
                  apiVersion: v1
                  fieldPath: spec.serviceAccountName
      imagePullSecrets:
        - name: $CTR_REGISTRY_CREDS_NAME
EOF

kubectl get pods      --no-headers -o wide --selector app="$SVC" -n "$ECHO_CONSUMER_NAMESPACE"
kubectl get endpoints --no-headers -o wide --selector app="$SVC" -n "$ECHO_CONSUMER_NAMESPACE"
kubectl get service                -o wide                       -n "$ECHO_CONSUMER_NAMESPACE"

for x in $(kubectl get service -n "$ECHO_CONSUMER_NAMESPACE" --selector app="$SVC" --no-headers | awk '{print $1}'); do
    kubectl get service "$x" -n "$ECHO_CONSUMER_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[*].ip}'
done
