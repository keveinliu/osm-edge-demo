#!make

TARGETS      := darwin/amd64 darwin/arm64 linux/amd64 linux/arm64
BINNAME      ?= osm
DIST_DIRS    := find * -type d -exec
CTR_REGISTRY ?= flomesh
CTR_TAG      ?= latest
VERIFY_TAGS  ?= false

GOPATH = $(shell go env GOPATH)
GOBIN  = $(GOPATH)/bin
GOX    = go run github.com/mitchellh/gox
SHA256 = sha256sum
ifeq ($(shell uname),Darwin)
	SHA256 = shasum -a 256
endif

VERSION ?= dev
BUILD_DATE ?=
GIT_SHA=$$(git rev-parse HEAD)
BUILD_DATE_VAR := github.com/openservicemesh/osm/pkg/version.BuildDate
BUILD_VERSION_VAR := github.com/openservicemesh/osm/pkg/version.Version
BUILD_GITCOMMIT_VAR := github.com/openservicemesh/osm/pkg/version.GitCommit
DOCKER_GO_VERSION = 1.17
DOCKER_BUILDX_PLATFORM ?= linux/amd64
# Value for the --output flag on docker buildx build.
# https://docs.docker.com/engine/reference/commandline/buildx_build/#output
DOCKER_BUILDX_OUTPUT ?= type=registry

LDFLAGS ?= "-X $(BUILD_DATE_VAR)=$(BUILD_DATE) -X $(BUILD_VERSION_VAR)=$(VERSION) -X $(BUILD_GITCOMMIT_VAR)=$(GIT_SHA) -s -w"

# These two values are combined and passed to go test
E2E_FLAGS ?= -installType=KindCluster
E2E_FLAGS_DEFAULT := -test.v -ginkgo.v -ginkgo.progress -ctrRegistry $(CTR_REGISTRY) -osmImageTag $(CTR_TAG)

# Installed Go version
# This is the version of Go going to be used to compile this project.
# It will be compared with the minimum requirements for OSM.
GO_VERSION_MAJOR = $(shell go version | cut -c 14- | cut -d' ' -f1 | cut -d'.' -f1)
GO_VERSION_MINOR = $(shell go version | cut -c 14- | cut -d' ' -f1 | cut -d'.' -f2)
GO_VERSION_PATCH = $(shell go version | cut -c 14- | cut -d' ' -f1 | cut -d'.' -f3)
ifeq ($(GO_VERSION_PATCH),)
GO_VERSION_PATCH := 0
endif

check-env:
ifndef CTR_REGISTRY
	$(error CTR_REGISTRY environment variable is not defined; see the .env.example file for more information; then source .env)
endif
ifndef CTR_TAG
	$(error CTR_TAG environment variable is not defined; see the .env.example file for more information; then source .env)
endif

.PHONY: proto
proto:
	protoc --proto_path=pkg/api/echo --go_out=pkg/api/echo --go-grpc_out=pkg/api/echo echo.proto

.PHONY: go-checks
go-checks: go-lint go-fmt go-mod-tidy

.PHONY: go-vet
go-vet:
	go vet ./...

.PHONY: go-lint
go-lint: embed-files-test
	docker run --rm -v $$(pwd):/app -w /app golangci/golangci-lint:latest golangci-lint run --config .golangci.yml

.PHONY: go-fmt
go-fmt:
	go fmt ./...

.PHONY: go-mod-tidy
go-mod-tidy:
	./scripts/go-mod-tidy.sh

.PHONY: kind-up
kind-up:
	./scripts/kind-with-registry.sh

.PHONY: kind-reset
kind-reset:
	kind delete cluster --name osm

local-run-echo-consumer:
	CONF_CONSUMER_FILE_PATH=${PWD}/misc/echo-consumer/client.yml \
	APP_LOG_CONF_FILE=${PWD}/misc/echo-consumer/log.yml \
	go run demo/cmd/echo-consumer/main.go

local-run-echo-grpc-server:
	go run demo/cmd/echo-grpc-server/main.go

local-run-echo-dubbo-server:
	CONF_PROVIDER_FILE_PATH=${PWD}/misc/echo-dubbo-server/server.yml \
	APP_LOG_CONF_FILE=${PWD}/misc/echo-dubbo-server/log.yml \
	go run demo/cmd/echo-dubbo-server/main.go

.env:
	cp .env.example .env

.PHONY: kind-demo
kind-demo: export CTR_REGISTRY=localhost:5000
kind-demo: .env kind-up
	./demo/run-osm-demo.sh

DEMO_TARGETS = echo-consumer echo-dubbo-server echo-grpc-server
# docker-build-echo-consumer, etc
DOCKER_DEMO_TARGETS = $(addprefix docker-build-, $(DEMO_TARGETS))
.PHONY: $(DOCKER_DEMO_TARGETS)
$(DOCKER_DEMO_TARGETS): NAME=$(@:docker-build-%=%)
$(DOCKER_DEMO_TARGETS):
	docker buildx build --builder osm --platform=$(DOCKER_BUILDX_PLATFORM) -o $(DOCKER_BUILDX_OUTPUT) -t $(CTR_REGISTRY)/osm-edge-demo-$(NAME):$(CTR_TAG) -f dockerfiles/Dockerfile.demo --build-arg GO_VERSION=$(DOCKER_GO_VERSION) --build-arg BINARY=$(NAME) .

.PHONY: docker-build-demo
docker-build-demo: $(DOCKER_DEMO_TARGETS)

.PHONY: buildx-context
buildx-context:
	@if ! docker buildx ls | grep -q "^osm "; then docker buildx create --name osm --driver-opt network=host; fi

check-image-exists-%: NAME=$(@:check-image-exists-%=%)
check-image-exists-%:
	@if [ "$(VERIFY_TAGS)" = "true" ]; then scripts/image-exists.sh $(CTR_REGISTRY)/$(NAME):$(CTR_TAG); fi

$(foreach target,$(DEMO_TARGETS),$(eval docker-build-$(target): check-image-exists-$(target) buildx-context))

docker-digest-%: NAME=$(@:docker-digest-%=%)
docker-digest-%:
	@docker buildx imagetools inspect $(CTR_REGISTRY)/$(NAME):$(CTR_TAG) --raw | $(SHA256) | awk '{print "$(NAME): sha256:"$$1}'

.PHONY: docker-digests-demo
docker-digests: $(addprefix docker-digest-, $(DEMO_TARGETS))

.PHONY: docker-build
docker-build: docker-build-demo

.PHONY: docker-build-cross-demo docker-build-cross
docker-build-cross-demo: DOCKER_BUILDX_PLATFORM=darwin/amd64,darwin/arm64,linux/amd64,linux/arm64
docker-build-cross-demo: docker-build-demo
docker-build-cross: docker-build-cross-demo


.PHONY: build-ci
build-ci:
	go build -v ./...

.PHONY: trivy-ci-setup
trivy-ci-setup:
	wget https://github.com/aquasecurity/trivy/releases/download/v0.23.0/trivy_0.23.0_Linux-64bit.tar.gz
	tar zxvf trivy_0.23.0_Linux-64bit.tar.gz
	echo $$(pwd) >> $(GITHUB_PATH)

# Show all vulnerabilities in logs
trivy-scan-verbose-%: NAME=$(@:trivy-scan-verbose-%=%)
trivy-scan-verbose-%:
	trivy image "$(CTR_REGISTRY)/$(NAME):$(CTR_TAG)"

# Exit if vulnerability exists
trivy-scan-fail-%: NAME=$(@:trivy-scan-fail-%=%)
trivy-scan-fail-%:
	trivy image --exit-code 1 --ignore-unfixed --severity MEDIUM,HIGH,CRITICAL "$(CTR_REGISTRY)/$(NAME):$(CTR_TAG)"

.PHONY: trivy-scan-images trivy-scan-images-fail trivy-scan-images-verbose
trivy-scan-images-verbose: $(addprefix trivy-scan-verbose-, $(OSM_TARGETS))
trivy-scan-images-fail: $(addprefix trivy-scan-fail-, $(OSM_TARGETS))
trivy-scan-images: trivy-scan-images-verbose trivy-scan-images-fail

.PHONY: shellcheck
shellcheck:
	shellcheck -x $(shell find . -name '*.sh')

.PHONY: install-git-pre-push-hook
install-git-pre-push-hook:
	./scripts/install-git-pre-push-hook.sh

# -------------------------------------------
#  release targets below
# -------------------------------------------

.PHONY: build-cross
build-cross: cmd/cli/chart.tgz
	GO111MODULE=on CGO_ENABLED=0 $(GOX) -ldflags $(LDFLAGS) -parallel=5 -output="_dist/{{.OS}}-{{.Arch}}/$(BINNAME)" -osarch='$(TARGETS)' ./cmd/cli

.PHONY: dist
dist:
	( \
		cd _dist && \
		$(DIST_DIRS) cp ../LICENSE {} \; && \
		$(DIST_DIRS) cp ../README.md {} \; && \
		$(DIST_DIRS) tar -zcf osm-edge-${VERSION}-{}.tar.gz {} \; && \
		$(DIST_DIRS) zip -r osm-edge-${VERSION}-{}.zip {} \; && \
		$(SHA256) osm-* > sha256sums.txt \
	)

.PHONY: release-artifacts
release-artifacts: build-cross dist
