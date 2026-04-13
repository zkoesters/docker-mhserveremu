# Makefile — Build and test automation for docker-mhserveremu images.
#
# Targets:
#   make build                              Build all image versions and variants.
#   make test                               Run the test suite against all images.
#   make all                                Build then test.
#   make build VERSION=1.0.0                Build a specific version (default + alpine).
#   make build VERSION=1.0.0 VARIANT=alpine Build only the alpine variant.
#
# Dependencies:
#   - Docker (with Buildx)
#   - Git
#   - Game data files: Calligraphy.sip & mu_cdata.sip in the repo root
#   - docker-library/official-images test framework (auto-cloned on first test)

REPO_NAME  ?= zkoesters
IMAGE_NAME ?= mhserveremu

LATEST_VERSION=1.0.1
do_default=true
do_alpine=true

DOCKER=docker
GIT=git

OFFIMG_LOCAL_CLONE=$(HOME)/official-images
OFFIMG_REPO_URL=https://github.com/docker-library/official-images.git
DOCKER_BUILDKIT ?= 1

export DOCKER_BUILDKIT

# Supported versions are inferred from Config.ini.template directories.
ALL_VERSIONS := $(sort $(foreach cfg,$(wildcard */Config.ini.template),$(cfg:%/Config.ini.template=%)))

# Map version directories to the upstream git branch they track.
# Versions whose directory name matches the branch are handled by the
# default value; only add entries here for exceptions (e.g. nightly→dev).
branch_nightly=dev

# Resolve the git branch for a given version. Falls back to the version
# name itself when no explicit mapping exists (e.g. "1.0.0" → "1.0.0").
branch = $(or $(branch_$(1)),$(1))

ifdef VERSION
ifeq (,$(filter $(VERSION),$(ALL_VERSIONS)))
$(error Unknown VERSION '$(VERSION)'; available versions: $(ALL_VERSIONS))
endif
VERSIONS=$(VERSION)
ifdef VARIANT
ifneq ($(VARIANT),default)
ifneq ($(VARIANT),alpine)
$(error Unknown VARIANT '$(VARIANT)'; expected 'default' or 'alpine')
endif
endif
do_default=false
do_alpine=false
ifeq ($(VARIANT),default)
do_default=true
endif
ifeq ($(VARIANT),alpine)
do_alpine=true
endif
endif
else
VERSIONS = $(ALL_VERSIONS)
endif

build: $(foreach version,$(VERSIONS),build-$(version))

all: build test

define build-version
build-$1:
ifeq ($(do_default),true)
	$(DOCKER) build --pull --no-cache \
		--build-arg MHSERVEREMU_BRANCH=$(call branch,$1) \
		--build-arg MHSERVEREMU_VERSION=$1 \
		-t $(REPO_NAME)/$(IMAGE_NAME):$(shell echo $1) \
		-f Dockerfile .
	$(DOCKER) images $(REPO_NAME)/$(IMAGE_NAME):$(shell echo $1)
endif
ifeq ($(do_alpine),true)
	$(DOCKER) build --pull --no-cache \
		--build-arg MHSERVEREMU_BRANCH=$(call branch,$1) \
		--build-arg MHSERVEREMU_VERSION=$1 \
		-t $(REPO_NAME)/$(IMAGE_NAME):$(shell echo $1)-alpine \
		-f Dockerfile.alpine .
	$(DOCKER) images $(REPO_NAME)/$(IMAGE_NAME):$(shell echo $1)-alpine
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
	$(OFFIMG_LOCAL_CLONE)/test/run.sh -c $(OFFIMG_LOCAL_CLONE)/test/config.sh -c test/mhserveremu-config.sh $(REPO_NAME)/$(IMAGE_NAME):$1
endif
ifeq ($(do_alpine),true)
	$(OFFIMG_LOCAL_CLONE)/test/run.sh -c $(OFFIMG_LOCAL_CLONE)/test/config.sh -c test/mhserveremu-config.sh $(REPO_NAME)/$(IMAGE_NAME):$1-alpine
endif
endef
$(foreach version,$(VERSIONS),$(eval $(call test-version,$(version))))

.PHONY: build all test-prepare test \
		$(foreach version,$(VERSIONS),build-$(version)) \
		$(foreach version,$(VERSIONS),test-$(version)) \
