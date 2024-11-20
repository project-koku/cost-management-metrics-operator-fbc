# Cost Management Metrics Operator FBC

File-Based Catalog for Cost Management Metrics Operator

## How to update

Updates are made to the [basic-template.yaml](catalog-templates/basic-template.yaml) file.

1. add new name and replaces to the `olm.channel`, e.g.:
```
      - name: costmanagement-metrics-operator.3.3.2
        replaces: costmanagement-metrics-operator.3.3.1
```

2. add a new `olm.bundle` pullspec image, e.g.:
```
  - image: registry.redhat.io/costmanagement/costmanagement-metrics-operator-bundle@sha256:01cab18a6af3cc819a936ce434004d5dce4495474e62bc116643eb753c25cd91
    schema: olm.bundle
```

3. Update the `OCP_VERSIONS` in the [Makefile](Makefile), if necessary.
4. Rebuild the FBCs (this will be very slow, especially the first time running this command):
```
$ make basic
```
