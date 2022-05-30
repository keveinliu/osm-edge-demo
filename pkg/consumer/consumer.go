package consumer

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/go-resty/resty/v2"
	"log"
	"net/http"
	"sync/atomic"
	"time"

	hessian "github.com/apache/dubbo-go-hessian2"
	"github.com/apache/dubbo-go/common/logger"
	"github.com/apache/dubbo-go/config"
	pb "github.com/cybwan/osm-edge-demo/pkg/api/echo"
	httpProto "github.com/cybwan/osm-edge-demo/pkg/http"
	"github.com/cybwan/osm-edge-demo/pkg/model"
	"github.com/cybwan/osm-edge-demo/pkg/router"
	"github.com/gin-gonic/gin"
	"github.com/pkg/errors"
	"google.golang.org/grpc"
	"istio.io/pkg/env"
)

var (
	PodName      = env.RegisterStringVar("POD_NAME", "consumer-local-xxx", "pod name")
	PodNamespace = env.RegisterStringVar("POD_NAMESPACE", "admin", "pod namespace")
	PodIp        = env.RegisterStringVar("POD_IP", "0.0.0.0", "pod ip")
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
	GrpcCli   pb.EchoClient
	HttpCli   *resty.Client
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

func (u *DownConsumer) HttpEcho(c *gin.Context) {
	logger.Debugf("start to test http get user")
	atomic.AddInt64(&u.IdCounter, 1)
	res, err := u.HttpCli.R().Get("/httpEcho")

	if err != nil {
		c.IndentedJSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": errors.Wrapf(err, "unexpected error from httpEcho").Error(),
		})
		return
	}
	echoRes := new(httpProto.EchoResponse)
	json.Unmarshal(res.Body(), echoRes)
	atomic.AddInt64(&u.IdCounter, 1)
	c.IndentedJSON(http.StatusOK, gin.H{
		"success":   true,
		"resultMap": echoRes,
	})
}

func (u *DownConsumer) GrpcEcho(c *gin.Context) {
	logger.Debugf("start to test grpc get id")
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()

	res, err := u.GrpcCli.UnaryEcho(ctx, &pb.EchoRequest{
		Id:      fmt.Sprintf("%d", u.IdCounter),
		Message: c.Request.RemoteAddr + " keepalive demo",
	})
	if err != nil {
		c.IndentedJSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": errors.Wrapf(err, "unexpected error from UnaryEcho").Error(),
		})
		return
	}

	atomic.AddInt64(&u.IdCounter, 1)
	c.IndentedJSON(http.StatusOK, gin.H{
		"success":   true,
		"resultMap": res,
	})
}

func (u *DownConsumer) Routes() []*router.Route {
	var routes []*router.Route

	ctlRoutes := []*router.Route{
		{
			Method:  "GET",
			Path:    "/httpEcho",
			Handler: u.HttpEcho,
		},
		{
			Method:  "GET",
			Path:    "/dubboEcho",
			Handler: u.DubboEcho,
		},
		{
			Method:  "GET",
			Path:    "/grpcEcho",
			Handler: u.GrpcEcho,
		},
	}

	routes = append(routes, ctlRoutes...)
	return routes
}

func grpcInit(addr string) pb.EchoClient {
	conn, err := grpc.Dial(addr, grpc.WithInsecure())
	if err != nil {
		log.Fatalf("did not connect: %v", err)
	}

	c := pb.NewEchoClient(conn)
	return c
}

func httpInit(httpServerAddr string) *resty.Client {
	// Create a Resty Client
	client := resty.New()
	// Retries are configured per client
	client.
		// Set retry count to non zero to enable retries
		SetRetryCount(3).
		// You can override initial retry wait time.
		// Default is 100 milliseconds.
		SetRetryWaitTime(5 * time.Second).
		// MaxWaitTime can be overridden as well.
		// Default is 2 seconds.
		SetRetryMaxWaitTime(20 * time.Second).
		// SetRetryAfter sets callback to calculate wait time between retries.
		// Default (nil) implies exponential backoff with jitter
		SetRetryAfter(func(client *resty.Client, resp *resty.Response) (time.Duration, error) {
			return 0, errors.New("quota exceeded")
		}).
		SetBaseURL(fmt.Sprintf("http://%s", httpServerAddr))
	return client
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
func GRPCInit(grpcServerAddr, httpServerAddr string) *router.Router {
	cli := &DownConsumer{
		EchoConsumer: EchoClient,
	}
	cli.GrpcCli = grpcInit(grpcServerAddr)
	rt := router.NewRouter(&router.Options{
		Addr:           ":8090",
		GinLogEnabled:  true,
		PprofEnabled:   false,
		MetricsEnabled: true,
	})

	rt.AddRoutes("index", rt.DefaultRoutes())
	rt.AddRoutes("user", cli.Routes())

	cli.HttpCli = httpInit(httpServerAddr)
	return rt
}
