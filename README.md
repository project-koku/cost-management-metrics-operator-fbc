# Cost Management Metrics Operator FBC

File-Based Catalog for Cost Management Metrics Operator

**note**: the catalogs differ depending on OCP version:
* 4.16 or earlier, bundle metadata must use the olm.bundle.object format
* 4.17 or later, bundle metadata must use the olm.csv.metadata format
The catalog for <=4.16 is stored in [catalog-old](catalog-old), whereas >=4.17 is stored in [catalog](catalog)

## How to update

Updates are made to the [basic-template.yaml](catalog-templates/basic-template.yaml) file and then a catalog is generated from the template. The template can be updated with a Make command.

1. in the [Makefile](Makefile), update `VERSION`, `PREVIOUS_VERSION`, and `REGISTRY_SHA` to the latest values:
```
VERSION ?= 3.3.1
PREVIOUS_VERSION ?= 3.3.0
REGISTRY_SHA ?= sha256:01cab18a6af3cc819a936ce434004d5dce4495474e62bc116643eb753c25cd91
```

2. run `make add-new-version` which will add the new version and pullspec to the template:
```
$ make add-new-version
```
which results in:
```
...
      - name: costmanagement-metrics-operator.3.3.1
        replaces: costmanagement-metrics-operator.3.3.0
    name: stable
    package: costmanagement-metrics-operator
    schema: olm.channel
...
  - image: registry.redhat.io/costmanagement/costmanagement-metrics-operator-bundle@sha256:01cab18a6af3cc819a936ce434004d5dce4495474e62bc116643eb753c25cd91
    schema: olm.bundle
schema: olm.template.basic
```

3. Rebuild the FBC (this will be very slow, especially the first time running this command). This command also validates the outputted FBC:
```
$ make catalog
```

4. (optional) In case you need to rebuild the bundle after you've already generated the FBC, run `make remove-new-version` to remove the added versions, THEN update the `REGISTRY_SHA` with the new bundle and redo the above steps.
