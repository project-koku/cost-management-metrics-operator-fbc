VERSION ?= 4.1.0
PREVIOUS_VERSION ?= 4.0.0
USER_WORKLOAD_REPO ?= quay.io/redhat-user-workloads/cost-mgmt-dev-tenant/costmanagement-metrics-operator/costmanagement-metrics-operator-bundle
REGISTRY_REPO ?= registry.redhat.io/costmanagement/costmanagement-metrics-operator-bundle
REGISTRY_SHA ?= sha256:84d65eed99300b0ba87369cbf9a9fc17a37781f8b6f9de2819d0a159f9071a6c

PWD=$(shell pwd)
OPERATOR_NAME=costmanagement-metrics-operator

TOPDIR=$(abspath $(dir $(PWD)))
BINDIR=${TOPDIR}/bin
DOCKER := $(shell which docker 2>/dev/null || which podman 2>/dev/null)

# Add the bin directory to the PATH
export PATH := $(BINDIR):$(PATH)
# A place to store the generated catalogs
CATALOG_DIR_OLD=${PWD}/catalog-old
CATALOG_DIR=${PWD}/catalog

# A place to store the operator catalog templates
OPERATOR_CATALOG_TEMPLATE_DIR = ${PWD}/catalog-template
CATALOG_TEMPLATE_FILENAME = basic-template.yaml

# Define the paths for both auth files
# NOTE: OPM v1.53.0+ a defined policy.json file in $HOME/.config/containers
# see release notes: https://github.com/operator-framework/operator-registry/releases/tag/v1.53.0
# You can follow this gist for a local compliant environment: https://gist.github.com/grokspawn/5d00e53c36b5a7b93a56549a7eebda91#readme.md
DOCKER_CONFIG := $(HOME)/.docker/config.json
CONTAINERS_AUTH := $(XDG_RUNTIME_DIR)/containers/auth.json

# A list of OCP versions to generate catalogs for
# This list can be customized to include the versions that are relevant to the operator
# DO NOT change this line (except for the versions) if you want to take advantage
# of the automated catalog promotion
OCP_VERSIONS=$(shell echo "v4.12 v4.13 v4.14 v4.15 v4.16 v4.17 v4.18 v4.19")

OS=$(shell go env GOOS)
ARCH=$(shell go env GOARCH)

OPM_VERSION ?= v1.56.0
OPM_FILENAME ?= opm-$(OPM_VERSION)
YQ_VERSION ?= v4.45.4
YQ_FILENAME ?= yq-$(YQ_VERSION)

## Location to install dependencies to
LOCALBIN ?= $(shell pwd)/bin
$(LOCALBIN):
	mkdir -p $(LOCALBIN)

.PHONY: catalog
catalog: clean opm
	mkdir -p ${CATALOG_DIR_OLD}/${OPERATOR_NAME}/ ${CATALOG_DIR}/${OPERATOR_NAME}/ && \
	$(OPM) alpha render-template basic -o yaml ${OPERATOR_CATALOG_TEMPLATE_DIR}/${CATALOG_TEMPLATE_FILENAME} > ${CATALOG_DIR_OLD}/${OPERATOR_NAME}/catalog.yaml;
	$(OPM) alpha render-template basic -o yaml ${OPERATOR_CATALOG_TEMPLATE_DIR}/${CATALOG_TEMPLATE_FILENAME} --migrate-level=bundle-object-to-csv-metadata > ${CATALOG_DIR}/${OPERATOR_NAME}/catalog.yaml;
	$(OPM) validate ${CATALOG_DIR_OLD}/${OPERATOR_NAME}
	$(OPM) validate ${CATALOG_DIR}/${OPERATOR_NAME}

	sed -i '' 's|$(USER_WORKLOAD_REPO)|$(REGISTRY_REPO)|g' ${OPERATOR_CATALOG_TEMPLATE_DIR}/${CATALOG_TEMPLATE_FILENAME} ${CATALOG_DIR_OLD}/${OPERATOR_NAME}/catalog.yaml ${CATALOG_DIR}/${OPERATOR_NAME}/catalog.yaml

.PHONY: add-new-version
add-new-version: yq
	$(YQ) -i eval 'select(.schema == "olm.template.basic").entries[] |= select(.schema == "olm.channel").entries += [{"name" : "$(OPERATOR_NAME).$(VERSION)", "replaces": "$(OPERATOR_NAME).$(PREVIOUS_VERSION)"}]' ${OPERATOR_CATALOG_TEMPLATE_DIR}/${CATALOG_TEMPLATE_FILENAME}
	$(YQ) -i '.entries += [{"image": "$(USER_WORKLOAD_REPO)@$(REGISTRY_SHA)", "schema": "olm.bundle"}]' ${OPERATOR_CATALOG_TEMPLATE_DIR}/${CATALOG_TEMPLATE_FILENAME}

.PHONY: remove-new-version
remove-new-version: yq
	$(YQ) -i eval 'select(.schema == "olm.template.basic").entries[] |= select(.schema == "olm.channel").entries -= [{"name" : "$(OPERATOR_NAME).$(VERSION)", "replaces": "$(OPERATOR_NAME).$(PREVIOUS_VERSION)"}]' ${OPERATOR_CATALOG_TEMPLATE_DIR}/${CATALOG_TEMPLATE_FILENAME}
	$(YQ) -i '.entries -= [{"image": "$(REGISTRY_REPO)@$(REGISTRY_SHA)", "schema": "olm.bundle"}]' ${OPERATOR_CATALOG_TEMPLATE_DIR}/${CATALOG_TEMPLATE_FILENAME}

.PHONY: create-catalog-dir
create-catalog-dir:
	mkdir -p $(CATALOG_DIR) $(CATALOG_DIR_OLD)

.PHONY: clean
clean: create-catalog-dir
	find $(CATALOG_DIR_OLD) -type d -name ${OPERATOR_NAME} -exec rm -rf {} +
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
