PREVIOUS_VERSION ?= 3.3.1
VERSION ?= 3.3.2

PWD=$(shell pwd)
OPERATOR_NAME=costmanagement-metrics-operator

TOPDIR=$(abspath $(dir $(PWD)))
BINDIR=${TOPDIR}/bin
DOCKER := $(shell which docker 2>/dev/null || which podman 2>/dev/null)

# Add the bin directory to the PATH
export PATH := $(BINDIR):$(PATH)
# A place to store the generated catalogs
CATALOG_DIR=${PWD}/catalog

# A place to store the operator catalog templates
OPERATOR_CATALOG_TEMPLATE_DIR = ${PWD}/catalog-template

# Define the paths for both auth files
DOCKER_CONFIG := $(HOME)/.docker/config.json
CONTAINERS_AUTH := $(XDG_RUNTIME_DIR)/containers/auth.json

# A list of OCP versions to generate catalogs for
# This list can be customized to include the versions that are relevant to the operator
# DO NOT change this line (except for the versions) if you want to take advantage
# of the automated catalog promotion
OCP_VERSIONS=$(shell echo "v4.12 v4.13 v4.14 v4.15 v4.16 v4.17" )

OPM_VERSION ?= v1.48.0
OPM_FILENAME ?= opm-$(OPM_VERSION)
YQ_VERSION ?= v4.2.0

## Location to install dependencies to
LOCALBIN ?= $(shell pwd)/bin
$(LOCALBIN):
	mkdir -p $(LOCALBIN)

.PHONY: basic
basic: clean opm
	mkdir -p ${CATALOG_DIR}/${OPERATOR_NAME}/ && \
	$(OPM) alpha render-template basic -o yaml ${OPERATOR_CATALOG_TEMPLATE_DIR}/basic-template.yaml > ${CATALOG_DIR}/${OPERATOR_NAME}/catalog.yaml; \

.PHONY: create-catalog-dir
create-catalog-dir:
	mkdir -p $(CATALOG_DIR)

.PHONY: clean
clean: create-catalog-dir
	find $(CATALOG_DIR) -type d -name ${OPERATOR_NAME} -exec rm -rf {} +

.PHONY: yq
YQ ?= $(LOCALBIN)/yq
yq: ## Download yq locally if necessary.
ifeq (,$(wildcard $(YQ)))
ifeq (, $(shell which yq 2>/dev/null))
	@{ \
	set -e ;\
	mkdir -p $(dir $(YQ)) ;\
	OS=$(shell go env GOOS) && ARCH=$(shell go env GOARCH) && \
	curl -sSLo $(YQ) https://github.com/mikefarah/yq/releases/download/$(YQ_VERSION)/yq_$${OS}_${{ARCH}} && chmod +x $(YQ)
	}
else
YQ = $(shell which yq)
endif
endif


.PHONY: opm
OPM ?= $(LOCALBIN)/$(OPM_FILENAME)
opm: ## Download opm locally if necessary.
ifeq (,$(wildcard $(OPM_FILENAME)))
ifeq (, $(shell which $(OPM_FILENAME) 2>/dev/null))
	@{ \
	set -e ;\
	mkdir -p $(dir $(OPM)) ;\
	OS=$(shell go env GOOS) && ARCH=$(shell go env GOARCH) && \
	curl -sSLo $(OPM) https://github.com/operator-framework/operator-registry/releases/download/$(OPM_VERSION)/$${OS}-$${ARCH}-opm ;\
	chmod +x $(OPM) ;\
	}
else
OPM = $(shell which $(OPM_FILENAME))
endif
endif
