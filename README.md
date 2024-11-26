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
VERSION ?= 3.3.2
PREVIOUS_VERSION ?= 3.3.1
REGISTRY_SHA ?= sha256:448e65667b5c167699778b0056a18b31dc7ed95022c803217a2786d27d21e945
```

2. run `make add-new-version` which will add the new version and pullspec to the template:
```
$ make add-new-version
```
which results in:
```
...
      - name: costmanagement-metrics-operator.3.3.2
        replaces: costmanagement-metrics-operator.3.3.1
    name: stable
    package: costmanagement-metrics-operator
    schema: olm.channel
...
  - image: quay.io/redhat-user-workloads/cost-mgmt-dev-tenant/costmanagement-metrics-operator/costmanagement-metrics-operator-bundle@sha256:448e65667b5c167699778b0056a18b31dc7ed95022c803217a2786d27d21e945
    schema: olm.bundle
schema: olm.template.basic
```

3. Rebuild the FBC (this will be very slow, especially the first time running this command). This command also validates the outputted FBC and perform post-processing to replace the `quay.io/redhat-user-workloads` test repo with the correct `registry.redhat.io/costmanagement` bundle repo in the FBCs and basic-template:
```
$ make catalog
```

4. (optional) In case you need to rebuild the bundle after you've already generated the FBC, run `make remove-new-version` to remove the added versions, THEN update the `REGISTRY_SHA` with the new bundle and redo the above steps.

## Gather FBC for QE

1. Get the releases associated with the commit sha for the PR which updated the FBCs:
```
$ KUBECONFIG=~/.kube/konflux kubectl get release -l pac.test.appstudio.openshift.io/sha=239a845fb3b253c0dafbeae07e4144c2832d5735
NAME                                                    SNAPSHOT                                          RELEASEPLAN                                       RELEASE STATUS   AGE
costmanagement-metrics-operator-fbc-v4-12-rtmmp-4wgpm   costmanagement-metrics-operator-fbc-v4-12-rtmmp   costmanagement-metrics-operator-stage-fbc-v4-12   Succeeded        3h2m
costmanagement-metrics-operator-fbc-v4-13-n2xgp-95m5v   costmanagement-metrics-operator-fbc-v4-13-n2xgp   costmanagement-metrics-operator-stage-fbc-v4-13   Succeeded        3h2m
costmanagement-metrics-operator-fbc-v4-14-x65bx-bccs5   costmanagement-metrics-operator-fbc-v4-14-x65bx   costmanagement-metrics-operator-stage-fbc-v4-14   Succeeded        3h1m
costmanagement-metrics-operator-fbc-v4-15-hbxf4-m7q44   costmanagement-metrics-operator-fbc-v4-15-hbxf4   costmanagement-metrics-operator-stage-fbc-v4-15   Succeeded        3h1m
costmanagement-metrics-operator-fbc-v4-16-bhxlx-6gx4f   costmanagement-metrics-operator-fbc-v4-16-bhxlx   costmanagement-metrics-operator-stage-fbc-v4-16   Succeeded        3h2m
costmanagement-metrics-operator-fbc-v4-17-tj4p5-4z948   costmanagement-metrics-operator-fbc-v4-17-tj4p5   costmanagement-metrics-operator-stage-fbc-v4-17   Succeeded        3h1m
```

The `RELEASE STATUS` should be `Succeeded`!

2. Get the component and image:
```
$ KUBECONFIG=~/.kube/konflux kubectl get snapshot -l pac.test.appstudio.openshift.io/sha=239a845fb3b253c0dafbeae07e4144c2832d5735 -o jsonpath='{range .items[*]}{@.spec.components[].name}{" "}{@.spec.components[].containerImage}{"\n"}{end}'
costmanagement-metrics-operator-fbc-component-v4-12 quay.io/redhat-user-workloads/cost-mgmt-dev-tenant/costmanagement-metrics-operator-fbc-component-v4-12@sha256:243f5ddd2d7cd758afcbbcdea118d70a78cf337fe82184f33cb33a72185ca0df
costmanagement-metrics-operator-fbc-component-v4-13 quay.io/redhat-user-workloads/cost-mgmt-dev-tenant/costmanagement-metrics-operator-fbc-component-v4-13@sha256:4bc223ef026c2da93ef4dbc0550f9c5e61fbe391225699241e4a46421e5e4a33
costmanagement-metrics-operator-fbc-component-v4-14 quay.io/redhat-user-workloads/cost-mgmt-dev-tenant/costmanagement-metrics-operator-fbc-component-v4-14@sha256:0bc13823aa724952c30af90045f69e80dca79b182babd5cb25971d50592949f7
costmanagement-metrics-operator-fbc-component-v4-15 quay.io/redhat-user-workloads/cost-mgmt-dev-tenant/costmanagement-metrics-operator-fbc-component-v4-15@sha256:0b0fae192d572f26a3a5d8667838c81eca598fbf8595159b431fd2bb89118670
costmanagement-metrics-operator-fbc-component-v4-16 quay.io/redhat-user-workloads/cost-mgmt-dev-tenant/costmanagement-metrics-operator-fbc-component-v4-16@sha256:4edbd45925c170b43a60441f2693a3e07f8bfc7e635f5cecf96bea2a185be8d5
costmanagement-metrics-operator-fbc-component-v4-17 quay.io/redhat-user-workloads/cost-mgmt-dev-tenant/costmanagement-metrics-operator-fbc-component-v4-17@sha256:503a802959536d725a318a21902641168bf7b68d36a7e9fcb9ac431608266ae1
```

3. These are the `CatalogSource` images and are passed to QE for testing.

## Configuring a cluster with FBC

1. install python dependencies:
```
pipenv install --deploy
```

2. run the `configure_cluster.py`, providing the image corresponding to the OCP verison under test. For example, on an OCP v4.16 clsuter:
```
pipenv run ./configure_cluster.py -i quay.io/redhat-user-workloads/cost-mgmt-dev-tenant/costmanagement-metrics-operator-fbc-component-v4-16@sha256:4edbd45925c170b43a60441f2693a3e07f8bfc7e635f5cecf96bea2a185be8d5
```

This will configure the cluster to:
a. disable default OperatorHub sources
b. install an ImageDigestMirrorSet which allows the cluster to pull the operator images which have not landed in registry.readhat.io yet.
c. install the CatalogSource to make the operater installable through Operator Hub.
