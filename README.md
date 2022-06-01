# osm-edge-demo
## 安装osm edge cli

https://github.com/flomesh-io/osm-edge/releases/tag/v1.1.0

## 下载demo工程

```
git clone https://github.com/cybwan/osm-edge-demo.git
cd osm-edge-demo
```

## 调整环境变量

```
make .env
#调整变量
vi .env
export K8S_INGRESS_NODE=osm-worker   #指定为要部署ingress的node
export CTR_REGISTRY_USERNAME=flomesh #按需设定
export CTR_REGISTRY_PASSWORD=flomesh #按需设定
```

## demo部署

```
./demo/run-osm-demo.sh
```

## 打开ingress端口转发

```
./scripts/port-forward-echo-ingress-pipy.sh
```

## 测试 

127.0.0.1调整为ingress所在node的ip

```
curl -i http://127.0.0.1:80/httpEcho
curl -i http://127.0.0.1:80/grpcEcho
curl -i http://127.0.0.1:80/dubboEcho
```

## 卸载

```
./demo/clean-kubernetes.sh
```

