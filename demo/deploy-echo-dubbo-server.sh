#!/bin/bash

set -aueo pipefail

# shellcheck disable=SC1091
source .env
VERSION=${1:-v1}
SVC="echo-dubbo-server-$VERSION"
USE_PRIVATE_REGISTRY="${USE_PRIVATE_REGISTRY:-true}"
KUBE_CONTEXT=$(kubectl config current-context)
ENABLE_MULTICLUSTER="${ENABLE_MULTICLUSTER:-false}"
KUBERNETES_NODE_ARCH="${KUBERNETES_NODE_ARCH:-amd64}"
KUBERNETES_NODE_OS="${KUBERNETES_NODE_OS:-linux}"

kubectl delete deployment "$SVC" -n "$ECHO_DUBBO_SERVER_NAMESPACE"  --ignore-not-found

echo -e "Deploy $SVC Service Account"
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: "$SVC"
  namespace: $ECHO_DUBBO_SERVER_NAMESPACE
EOF

echo -e "Deploy $SVC Service"
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: $SVC
  namespace: $ECHO_DUBBO_SERVER_NAMESPACE
  labels:
    app: echo-dubbo-server
spec:
  ports:
  - port: 20002
    name: dubbo-port
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
  namespace: $ECHO_DUBBO_SERVER_NAMESPACE
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
        - image: "${CTR_REGISTRY}/osm-edge-demo-echo-dubbo-server:${CTR_TAG}"
          imagePullPolicy: Always
          name: $SVC
          ports:
            - containerPort: 14001
              name: web
            - containerPort: 20002
              name: tcp-dubbo
              protocol: TCP
          command: ["/echo-dubbo-server"]
          env:
            - name: IDENTITY
              value: ${SVC}.${KUBE_CONTEXT}
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
            - name: APP_LOG_CONF_FILE
              value: "/config/log.yml"
            - name: CONF_PROVIDER_FILE_PATH
              value: "/config/server.yml"
      imagePullSecrets:
        - name: $CTR_REGISTRY_CREDS_NAME
EOF

kubectl get pods      --no-headers -o wide --selector app="$SVC" -n "$ECHO_DUBBO_SERVER_NAMESPACE"
kubectl get endpoints --no-headers -o wide --selector app="$SVC" -n "$ECHO_DUBBO_SERVER_NAMESPACE"
kubectl get service                -o wide                       -n "$ECHO_DUBBO_SERVER_NAMESPACE"

for x in $(kubectl get service -n "$ECHO_DUBBO_SERVER_NAMESPACE" --selector app="$SVC" --no-headers | awk '{print $1}'); do
    kubectl get service "$x" -n "$ECHO_DUBBO_SERVER_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[*].ip}'
done
