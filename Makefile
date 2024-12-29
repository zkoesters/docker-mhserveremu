REPO_NAME  ?= zkoesters
IMAGE_NAME ?= mhserveremu
LATEST_VERSION=0.4.0

DOCKER=docker
GIT=git

OFFIMG_LOCAL_CLONE=$(HOME)/official-images
OFFIMG_REPO_URL=https://github.com/docker-library/official-images.git

ifdef VERSION
    VERSIONS=$(VERSION)
else
    VERSIONS = $(foreach df,$(wildcard */Dockerfile),$(df:%/Dockerfile=%))
endif

build: $(foreach version,$(VERSIONS),build-$(version))

all: build test

define build-version
build-$1:
	$(DOCKER) build --pull -t $(REPO_NAME)/$(IMAGE_NAME):$(shell echo $1) -f $1/Dockerfile .
	$(DOCKER) images          $(REPO_NAME)/$(IMAGE_NAME):$(shell echo $1)
endef
$(foreach version,$(VERSIONS),$(eval $(call build-version,$(version))))

test-prepare:
ifeq ("$(wildcard $(OFFIMG_LOCAL_CLONE))","")
	$(GIT) clone $(OFFIMG_REPO_URL) $(OFFIMG_LOCAL_CLONE)
endif

test: $(foreach version,$(VERSIONS),test-$(version))

define test-version
test-$1: test-prepare build-$1
	$(OFFIMG_LOCAL_CLONE)/test/run.sh -c $(OFFIMG_LOCAL_CLONE)/test/config.sh -c test/mhserveremu-config.sh $(REPO_NAME)/$(IMAGE_NAME):$(version)
endef
$(foreach version,$(VERSIONS),$(eval $(call test-version,$(version))))

.PHONY: build all test-prepare test \
		$(foreach version,$(VERSIONS),build-$(version)) \
        $(foreach version,$(VERSIONS),test-$(version)) \