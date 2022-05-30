package dubbo

import (
	"context"
	hessian "github.com/apache/dubbo-go-hessian2"
	"github.com/apache/dubbo-go/common/logger"
	"github.com/apache/dubbo-go/config"
	"github.com/cybwan/osm-edge-demo/pkg/model"
	"github.com/cybwan/osm-edge-demo/pkg/router"
	"github.com/gin-gonic/gin"
	"net/http"
)

var EchoClient = new(EchoConsumer)

func init() {
	gin.SetMode("release")
	config.SetConsumerService(EchoClient)
	hessian.RegisterPOJO(&model.Echo{})
}

type EchoConsumer struct {
	GetEcho func(ctx context.Context, req []interface{}, rsp *model.Echo) error
}

type DownConsumer struct {
	IdCounter int64
	*EchoConsumer
}

func (u *EchoConsumer) Reference() string {
	return "EchoProvider"
}

func (u *DownConsumer) DubboEcho(c *gin.Context) {
	name := c.DefaultQuery("name", "hello")

	logger.Debugf("start to test dubbo get Echo name: %s", name)
	echo := new(model.Echo)
	err := u.GetEcho(context.TODO(), []interface{}{name}, echo)
	if err != nil {
		c.IndentedJSON(http.StatusBadRequest, gin.H{
			"success":   false,
			"message":   err.Error(),
			"resultMap": nil,
		})
		return
	}
	logger.Debugf("dubbo response result: %#v\n", err)
	c.IndentedJSON(http.StatusOK, gin.H{
		"success":   true,
		"resultMap": echo,
	})
}

func (u *DownConsumer) Routes() []*router.Route {
	var routes []*router.Route

	ctlRoutes := []*router.Route{
		{
			Method:  "GET",
			Path:    "/dubboEcho",
			Handler: u.DubboEcho,
		},
	}

	routes = append(routes, ctlRoutes...)
	return routes
}

// DefaultHealhRoutes ...
func DefaultHealthRoutes() []*router.Route {
	var routes []*router.Route

	appRoutes := []*router.Route{
		{
			Method:  "GET",
			Path:    "/live",
			Handler: router.LiveHandler,
		},
		{
			Method:  "GET",
			Path:    "/ready",
			Handler: router.LiveHandler,
		},
	}

	routes = append(routes, appRoutes...)
	return routes
}

//
func GinInit() *router.Router {
	rt := router.NewRouter(router.DefaultOption())
	rt.AddRoutes("index", rt.DefaultRoutes())
	rt.AddRoutes("health", DefaultHealthRoutes())
	return rt
}

//
func CliInit() *router.Router {
	cli := &DownConsumer{
		EchoConsumer: EchoClient,
	}
	rt := router.NewRouter(&router.Options{
		Addr:           ":8090",
		GinLogEnabled:  false,
		PprofEnabled:   false,
		MetricsEnabled: false,
	})

	rt.AddRoutes("index", rt.DefaultRoutes())
	rt.AddRoutes("user", cli.Routes())

	return rt
}
