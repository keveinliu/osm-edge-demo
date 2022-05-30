package order

import (
	"context"
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
			Id: 1,
			Meta: map[string]string{
				"PodIp":        PodIp.Get(),
				"PodName":      PodName.Get(),
				"PodNamespace": PodNamespace.Get(),
				"Time":         time.Now().String(),
			},
		},
	}
}

func (o *EchoProvider) GetEcho(ctx context.Context, req []interface{}) (*model.Echo, error) {
	echo := o.Default
	atomic.AddInt64(&echo.Id, 1)
	echo.Meta["Time"] = time.Now().String()
	return echo, nil
}

func (o *EchoProvider) Reference() string {
	return "EchoProvider"
}
