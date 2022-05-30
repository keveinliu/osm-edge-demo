package grpc

import (
	"context"
	"log"
	"net"
	"os"
	"os/signal"
	"sync/atomic"

	"google.golang.org/grpc"

	"time"

	pb "github.com/cybwan/osm-edge-demo/pkg/api/echo"
	"istio.io/pkg/env"
)

var (
	PodName      = env.RegisterStringVar("POD_NAME", "grpc-test-xxx", "pod name")
	PodNamespace = env.RegisterStringVar("POD_NAMESPACE", "default", "pod namespace")
	PodIp        = env.RegisterStringVar("POD_IP", "0.0.0.0", "pod ip")
)

// server implements EchoServer.
type Server struct {
	Connter int64
	pb.UnimplementedEchoServer
}

func NewServer() *Server {
	return new(Server)
}
func (s *Server) UnaryEcho(ctx context.Context, req *pb.EchoRequest) (*pb.EchoResponse, error) {
	atomic.AddInt64(&s.Connter, 1)
	return &pb.EchoResponse{
		Id: req.Id,
		Meta: map[string]string{
			"PodName":      PodName.Get(),
			"PodNamespace": PodNamespace.Get(),
			"PodIp":        PodIp.Get(),
			"Time":         time.Now().String(),
		},
	}, nil
}

// RunServer runs gRPC service to publish ToDo service
func RunServer(ctx context.Context, s pb.EchoServer, port string) error {
	listen, err := net.Listen("tcp", ":"+port)
	if err != nil {
		return err
	}

	// gRPC server statup options
	opts := []grpc.ServerOption{}

	// register service
	server := grpc.NewServer(opts...)
	pb.RegisterEchoServer(server, s)

	// graceful shutdown
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt)
	go func() {
		for range c {
			// sig is a ^C, handle it
			log.Println("shutting down gRPC server...")

			server.GracefulStop()

			<-ctx.Done()
		}
	}()

	// start gRPC server
	log.Println("starting gRPC server...")
	return server.Serve(listen)
}
