package order

import (
	"context"
	"log"
	"sync/atomic"
	"time"

	hessian "github.com/apache/dubbo-go-hessian2"
	"github.com/apache/dubbo-go/config"
	"github.com/cybwan/osm-edge-demo/pkg/model"
	"istio.io/pkg/env"
)

func init() {
	config.SetProviderService(NewProvider())
	// ------for hessian2------
	hessian.RegisterPOJO(&model.Echo{})
}

var (
	PodName      = env.RegisterStringVar("POD_NAME", "dubbo-local-echo-xxx", "pod name")
	PodNamespace = env.RegisterStringVar("POD_NAMESPACE", "admin", "pod namespace")
	PodIp        = env.RegisterStringVar("POD_IP", "0.0.0.0", "pod ip")
)

type EchoProvider struct {
	Cache   map[string]*model.Echo
	Default *model.Echo
}

func NewProvider() *EchoProvider {
	return &EchoProvider{
		Cache: make(map[string]*model.Echo),
		Default: &model.Echo{
			Id:           1,
			Type:         "local",
			Name:         "hello",
			PodName:      PodName.Get(),
			PodNamespace: PodNamespace.Get(),
			PodIp:        PodIp.Get(),
			Time:         time.Now(),
		},
	}
}

func (o *EchoProvider) GetEcho(ctx context.Context, req []interface{}) (*model.Echo, error) {
	log.Printf("req :%#v", req)
	var echo *model.Echo
	for _, item := range req {
		if _name, ok := item.(string); ok {
			log.Printf("parse name: %s", _name)
			if _tmp, ok := o.Cache[_name]; ok {
				echo = _tmp
				break
			}
		}
	}

	if echo == nil {
		log.Printf("use delault echo")
		echo = o.Default
	}

	echo.Time = time.Now()
	log.Printf("echo:%#v", echo)
	atomic.AddInt64(&echo.Id, 1)
	return echo, nil
}

func (o *EchoProvider) Reference() string {
	return "EchoProvider"
}
