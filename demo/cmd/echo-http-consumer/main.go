package main

import (
	"context"
	"flag"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/apache/dubbo-go/common/logger"
	consumer "github.com/cybwan/osm-edge-demo/pkg/consumer/http"
)

// Config is configuration for Server
type Config struct {
	httpServerAddr string
}

func main() {
	var cfg Config
	flag.StringVar(&cfg.httpServerAddr, "http-server", "127.0.0.1:20003", "HTTP server in format host:port")
	flag.Parse()

	g := consumer.GinInit()
	r := consumer.CliInit(cfg.httpServerAddr)

	ctx, cancelFunc := context.WithCancel(context.Background())
	go g.StartWarp(ctx.Done())
	go r.StartWarp(ctx.Done())
	initSignal(cancelFunc)
}

func initSignal(cancelFunc func()) {
	signals := make(chan os.Signal, 1)
	// It is not possible to block SIGKILL or syscall.SIGSTOP
	signal.Notify(signals, os.Interrupt, os.Kill, syscall.SIGHUP,
		syscall.SIGQUIT, syscall.SIGTERM, syscall.SIGINT)
	for {
		sig := <-signals
		logger.Infof("get signal %s", sig.String())
		switch sig {
		case syscall.SIGHUP:
			// reload()
		default:
			logger.Info("call cancelFunc")
			cancelFunc()
			ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
			<-ctx.Done()
			cancel()
			// The program exits normally or timeout forcibly exits.
			logger.Info("app exit now...")
			return
		}
	}
}
