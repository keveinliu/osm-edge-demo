package grpc

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"sync/atomic"
	"time"

	"github.com/apache/dubbo-go/common/logger"
	pb "github.com/cybwan/osm-edge-demo/pkg/api/echo"
	"github.com/cybwan/osm-edge-demo/pkg/router"
	"github.com/gin-gonic/gin"
	"github.com/pkg/errors"
	"google.golang.org/grpc"
)

func init() {
	gin.SetMode("release")
}

type DownConsumer struct {
	IdCounter int64
	GrpcCli   pb.EchoClient
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
func CliInit(grpcServerAddr string) *router.Router {
	cli := new(DownConsumer)
	cli.GrpcCli = grpcInit(grpcServerAddr)
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
