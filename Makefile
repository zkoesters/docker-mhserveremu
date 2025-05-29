REPO_NAME  ?= zkoesters
IMAGE_NAME ?= mhserveremu

LATEST_VERSION=0.6.0
do_default=true
do_alpine=true

DOCKER=docker
GIT=git

OFFIMG_LOCAL_CLONE=$(HOME)/official-images
OFFIMG_REPO_URL=https://github.com/docker-library/official-images.git

ifdef VERSION
	VERSIONS=$(VERSION)
	ifdef VARIANT
		do_default=false
		do_alpine=false
		ifeq ($(VARIANT),default)
			do_default=true
		endif
		ifeq ($(VARIANT),alpine)
			do_alpine=true
		endif
	endif
	ifeq ("$(wildcard $(VERSION)/alpine)","")
    	do_alpine=false
	endif
else
	VERSIONS = $(foreach df,$(wildcard */Dockerfile),$(df:%/Dockerfile=%))
endif

build: $(foreach version,$(VERSIONS),build-$(version))

all: build test

define build-version
build-$1:
ifeq ($(do_default),true)
	$(DOCKER) build --pull --no-cache -t $(REPO_NAME)/$(IMAGE_NAME):$(shell echo $1) -f $1/Dockerfile .
	$(DOCKER) images                     $(REPO_NAME)/$(IMAGE_NAME):$(shell echo $1)
endif
ifeq ($(do_alpine),true)
ifneq ("$(wildcard $1/alpine)","")
	$(DOCKER) build --pull --no-cache -t $(REPO_NAME)/$(IMAGE_NAME):$(shell echo $1)-alpine -f $1/alpine/Dockerfile .
	$(DOCKER) images                     $(REPO_NAME)/$(IMAGE_NAME):$(shell echo $1)-alpine
endif
endif
endef
$(foreach version,$(VERSIONS),$(eval $(call build-version,$(version))))

test-prepare:
ifeq ("$(wildcard $(OFFIMG_LOCAL_CLONE))","")
	$(GIT) clone $(OFFIMG_REPO_URL) $(OFFIMG_LOCAL_CLONE)
endif

test: $(foreach version,$(VERSIONS),test-$(version))

define test-version
test-$1: test-prepare build-$1
ifeq ($(do_default),true)
	$(OFFIMG_LOCAL_CLONE)/test/run.sh -c $(OFFIMG_LOCAL_CLONE)/test/config.sh -c test/mhserveremu-config.sh $(REPO_NAME)/$(IMAGE_NAME):$(version)
endif
ifeq ($(do_alpine),true)
ifneq ("$(wildcard $1/alpine)","")
	$(OFFIMG_LOCAL_CLONE)/test/run.sh -c $(OFFIMG_LOCAL_CLONE)/test/config.sh -c test/mhserveremu-config.sh $(REPO_NAME)/$(IMAGE_NAME):$(version)-alpine
endif
endif
endef
$(foreach version,$(VERSIONS),$(eval $(call test-version,$(version))))

.PHONY: build all test-prepare test \
		$(foreach version,$(VERSIONS),build-$(version)) \
		$(foreach version,$(VERSIONS),test-$(version)) \