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

echo -e "Deploy $SVC ConfigMap"
kubectl apply  -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: echo-dubbo-server-config
  namespace: $ECHO_DUBBO_SERVER_NAMESPACE
  labels:
    app: echo-dubbo-server
data:
  log.yml: |
    level: "debug"
    development: true
    disableCaller: true
    disableStacktrace: true
    sampling:
    encoding: "console"

    # encoder
    encoderConfig:
      messageKey: "message"
      levelKey: "level"
      timeKey: "time"
      nameKey: "logger"
      callerKey: "caller"
      stacktraceKey: "stacktrace"
      lineEnding: ""
      levelEncoder: "capitalColor"
      timeEncoder: "iso8601"
      durationEncoder: "seconds"
      callerEncoder: "short"
      nameEncoder: ""

    outputPaths:
      - "stderr"
    errorOutputPaths:
      - "stderr"
    initialFields:
  server.yml: |
    # application config
    application:
      organization : "flomesh.io"
      name : "osm-edge demo"
      module : "osm-edge echo server by dubbo"
      version : "0.0.1"
      owner : "cybwan"
      environment : "release"

    services:
      "EchoProvider":
        protocol : "dubbo"
        interface : "io.flemsh.osm.Echo.EchoProvider"
        loadbalance: "random"
        warmup: "100"
        cluster: "failover"
        methods:
          - name: "GetEcho"
            retries: 1
            loadbalance: "random"

    protocols:
      "dubbo":
        name: "dubbo"
        #    ip : "127.0.0.1"
        port: 20002

    protocol_conf:
      dubbo:
        session_number: 700
        session_timeout: "20s"
        getty_session_param:
          compress_encoding: false
          tcp_no_delay: true
          tcp_keep_alive: true
          keep_alive_period: "120s"
          tcp_r_buf_size: 262144
          tcp_w_buf_size: 65536
          pkg_rq_size: 1024
          pkg_wq_size: 512
          tcp_read_timeout: "5s"
          tcp_write_timeout: "5s"
          wait_timeout: "1s"
          max_msg_len: 1024
          session_name: "server"
EOF

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
      volumes:
        - name: config
          configMap:
            name: echo-dubbo-server-config
            defaultMode: 420
      containers:
        - image: "${CTR_REGISTRY}/osm-edge-demo-echo-dubbo-server:${CTR_TAG}"
          imagePullPolicy: Always
          name: $SVC
          volumeMounts:
            - name: config
              mountPath: "/config"
          ports:
            - containerPort: 14001
              name: web
            - containerPort: 20002
              name: tcp-dubbo
              protocol: TCP
          command: ["/echo-dubbo-server"]
          args: ["--grpc-port", "20002"]
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
