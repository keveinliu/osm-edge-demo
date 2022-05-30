package http

import (
	"encoding/json"
	"fmt"
	"io"
	"istio.io/pkg/env"
	"net/http"
	"sync/atomic"
	"time"
)

var (
	PodName      = env.RegisterStringVar("POD_NAME", "http-test-xxx", "pod name")
	PodNamespace = env.RegisterStringVar("POD_NAMESPACE", "default", "pod namespace")
	PodIp        = env.RegisterStringVar("POD_IP", "0.0.0.0", "pod ip")
)

type EchoResponse struct {
	Id   string
	Meta map[string]string
}

type Server struct {
	Connter int64
}

func NewServer() *Server {
	return new(Server)
}

func (s *Server) httpEcho(w http.ResponseWriter, r *http.Request) {
	atomic.AddInt64(&s.Connter, 1)
	echo := EchoResponse{
		Id: fmt.Sprintf("%d", s.Connter),
		Meta: map[string]string{
			"PodName":      PodName.Get(),
			"PodNamespace": PodNamespace.Get(),
			"PodIp":        PodIp.Get(),
			"Time":         time.Now().String(),
		},
	}
	bytes, _ := json.Marshal(echo)
	w.Header().Set("Content-Type", "application/json")
	io.WriteString(w, string(bytes))
}

func RunServer(s *Server, port string) error {
	http.HandleFunc("/httpEcho", s.httpEcho)
	return http.ListenAndServe(fmt.Sprintf(":%s", port), nil)
}
