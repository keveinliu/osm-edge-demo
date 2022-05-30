package http

import (
	"encoding/json"
	"fmt"
	"github.com/go-resty/resty/v2"
	"net/http"
	"sync/atomic"
	"time"

	"github.com/apache/dubbo-go/common/logger"
	"github.com/cybwan/osm-edge-demo/pkg/router"
	httpSrv "github.com/cybwan/osm-edge-demo/pkg/server/http"
	"github.com/gin-gonic/gin"
	"github.com/pkg/errors"
)

func init() {
	gin.SetMode("release")
}

type DownConsumer struct {
	IdCounter int64
	HttpCli   *resty.Client
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
	echoRes := new(httpSrv.EchoResponse)
	json.Unmarshal(res.Body(), echoRes)
	atomic.AddInt64(&u.IdCounter, 1)
	c.IndentedJSON(http.StatusOK, gin.H{
		"success":   true,
		"resultMap": echoRes,
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
	}

	routes = append(routes, ctlRoutes...)
	return routes
}

func httpCliInit(httpServerAddr string) *resty.Client {
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
func CliInit(httpServerAddr string) *router.Router {
	cli := new(DownConsumer)
	rt := router.NewRouter(&router.Options{
		Addr:           ":8090",
		GinLogEnabled:  false,
		PprofEnabled:   false,
		MetricsEnabled: false,
	})

	rt.AddRoutes("index", rt.DefaultRoutes())
	rt.AddRoutes("user", cli.Routes())

	cli.HttpCli = httpCliInit(httpServerAddr)
	return rt
}
