#!/bin/bash

./scripts/port-forward-echo-grpc-server-v1.sh &
./scripts/port-forward-echo-dubbo-server-v1.sh &
./scripts/port-forward-echo-consumer-v1.sh &

wait

