.DEFAULT: all
.PHONY: all clean image publish-image minikube-publish

DH_ORG=timothyrr
VERSION=$(shell git symbolic-ref --short HEAD)-$(shell git rev-parse --short HEAD)-arm64
SUDO=$(shell docker info >/dev/null 2>&1 || echo "sudo -E")

all: image

clean:
	rm -f cmd/kured/kured
	rm -rf ./build

godeps=$(shell go list -f '{{join .Deps "\n"}}' $1 | grep -v /vendor/ | xargs go list -f '{{if not .Standard}}{{ $$dep := . }}{{range .GoFiles}}{{$$dep.Dir}}/{{.}} {{end}}{{end}}')

DEPS=$(call godeps,./cmd/kured)

cmd/kured/kured: $(DEPS)
cmd/kured/kured: cmd/kured/*.go
	CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -ldflags "-X main.version=$(VERSION)" -o $@ cmd/kured/*.go

build/.image.done: cmd/kured/Dockerfile cmd/kured/kured
	mkdir -p build
	cp $^ build
	$(SUDO) docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
	$(SUDO) docker buildx create --use --config /root/config.toml --name auto123 --platform=linux/arm64
	$(SUDO) docker buildx inspect --bootstrap auto123
	$(SUDO) docker buildx build --push -t 192.168.1.145:31551/docker/images/kured:$(VERSION) -f build/Dockerfile ./build
	touch $@

image: build/.image.done

publish-image: image
	$(SUDO) docker push docker.io/$(DH_ORG)/kured:$(VERSION)

minikube-publish: image
	$(SUDO) docker save docker.io/$(DH_ORG)/kured | (eval $$(minikube docker-env) && docker load)
