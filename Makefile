VERSION ?= 3.3.1
PREVIOUS_VERSION ?= 3.3.0
PULLSPEC ?= registry.redhat.io/costmanagement/costmanagement-metrics-operator-bundle@sha256:01cab18a6af3cc819a936ce434004d5dce4495474e62bc116643eb753c25cd91

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
CATALOG_TEMPLATE_FILENAME = basic-template.yaml

# Define the paths for both auth files
DOCKER_CONFIG := $(HOME)/.docker/config.json
CONTAINERS_AUTH := $(XDG_RUNTIME_DIR)/containers/auth.json

# A list of OCP versions to generate catalogs for
# This list can be customized to include the versions that are relevant to the operator
# DO NOT change this line (except for the versions) if you want to take advantage
# of the automated catalog promotion
OCP_VERSIONS=$(shell echo "v4.12 v4.13 v4.14 v4.15 v4.16 v4.17" )

OS=$(shell go env GOOS)
ARCH=$(shell go env GOARCH)

OPM_VERSION ?= v1.48.0
OPM_FILENAME ?= opm-$(OPM_VERSION)
YQ_VERSION ?= v4.44.5
YQ_FILENAME ?= yq-$(YQ_VERSION)

## Location to install dependencies to
LOCALBIN ?= $(shell pwd)/bin
$(LOCALBIN):
	mkdir -p $(LOCALBIN)

.PHONY: catalog
catalog: clean opm
	mkdir -p ${CATALOG_DIR}/${OPERATOR_NAME}/ && \
	$(OPM) alpha render-template basic -o json ${OPERATOR_CATALOG_TEMPLATE_DIR}/${CATALOG_TEMPLATE_FILENAME} > ${CATALOG_DIR}/${OPERATOR_NAME}/catalog.json;
	$(OPM) validate ${CATALOG_DIR}/${OPERATOR_NAME}

.PHONY: add-new-version
add-new-version: yq
	$(YQ) -i eval 'select(.schema == "olm.template.basic").entries[] |= select(.schema == "olm.channel").entries += [{"name" : "$(OPERATOR_NAME).$(VERSION)", "replaces": "$(OPERATOR_NAME).$(PREVIOUS_VERSION)"}]' ${OPERATOR_CATALOG_TEMPLATE_DIR}/${CATALOG_TEMPLATE_FILENAME}
	$(YQ) -i '.entries += [{"image": "$(PULLSPEC)", "schema": "olm.bundle"}]' ${OPERATOR_CATALOG_TEMPLATE_DIR}/${CATALOG_TEMPLATE_FILENAME}

.PHONY: create-catalog-dir
create-catalog-dir:
	mkdir -p $(CATALOG_DIR)

.PHONY: clean
clean: create-catalog-dir
	find $(CATALOG_DIR) -type d -name ${OPERATOR_NAME} -exec rm -rf {} +


.PHONY: yq
YQ = $(LOCALBIN)/$(YQ_FILENAME)
yq: ## Download opm locally if necessary.
ifeq (,$(wildcard $(YQ)))
ifeq (,$(shell which $(YQ) 2>/dev/null))
	@{ \
	set -e ;\
	mkdir -p $(dir $(YQ)) ;\
	curl -sSLo $(YQ) https://github.com/mikefarah/yq/releases/download/$(YQ_VERSION)/yq_$(OS)_$(ARCH) ;\
	chmod +x $(YQ) ;\
	}
else
YQ = $(shell which $(YQ))
endif
endif


.PHONY: opm
OPM ?= $(LOCALBIN)/$(OPM_FILENAME)
opm: ## Download opm locally if necessary.
ifeq (,$(wildcard $(OPM)))
ifeq (, $(shell which $(OPM) 2>/dev/null))
	@{ \
	set -e ;\
	mkdir -p $(dir $(OPM)) ;\
	curl -sSLo $(OPM) https://github.com/operator-framework/operator-registry/releases/download/$(OPM_VERSION)/$(OS)-$(ARCH)-opm ;\
	chmod +x $(OPM) ;\
	}
else
OPM = $(shell which $(OPM))
endif
endif
