# Tekton CI Documentation

This directory contains repository-owned Tekton assets for CI execution,
including build definitions, pull-request/push triggers, pipelines, tasks, and
versioned PipelineRuns.

## Architecture and upstream baseline

The local integration pipeline is:

- [`.tekton/pipelines/deploy-fbc-operator-with-iqe.yaml`](pipelines/deploy-fbc-operator-with-iqe.yaml)

It extends the upstream `deploy-fbc-operator` behavior by preserving the
baseline deploy sequence and adding IQE execution after operator deployment.
Ephemeral clusters are provisioned via **OpenShift CI** (`provision-ephemeral-cluster`
on cluster profile `aws-konflux-prod`), not the legacy EaaS path.

Upstream baseline references:

- [Konflux integration examples repository](https://github.com/konflux-ci/integration-examples)
- [Shared build definitions repository](https://github.com/konflux-ci/build-definitions)
- [Upstream deploy-fbc-operator pipeline](https://github.com/konflux-ci/tekton-integration-catalog/tree/main/pipelines/deploy-fbc-operator)
- [Tekton integration catalog repository](https://github.com/konflux-ci/tekton-integration-catalog)
- [openshift/konflux-tasks](https://github.com/openshift/konflux-tasks) (`provision-ephemeral-cluster`)

Current high-level runtime flow:

1. Parse metadata and fetch mirror-set configuration.
2. Resolve bundle image (parallel):
   - `get-unreleased-bundle` — uses upstream step action with `onError: continue`
     and a 10-minute task timeout; discovers unreleased bundles from the FBC
     fragment and resolves mirror substitution.
   - `resolve-bundle-override` — normalizes the optional
     `RELEASED_BUNDLE_IMAGE_OVERRIDE` parameter.
3. `select-bundle-image` — converges both results: prefers the unreleased
   bundle when available, falls back to the override, or leaves
   `selectedBundle` empty when neither is present.
4. Pick cluster params, provision an ephemeral cluster via OpenShift CI /
   HyperShift (`aws-konflux-prod`), and deploy the operator.
5. Run IQE operator coverage.
6. Run final verification checks (for example image-source validation).

### Supported integration path

The supported Konflux integration path for this repository is the **IQE**
pipeline (`deploy-fbc-operator-with-iqe` / `deploy-fbc-operator-iqe-its-v4-*`).
Deploy-only smoke ITS were removed from GitOps; do not treat a green smoke-only
run as the primary validation for FBC changes.

## False greens (read this before trusting Succeeded)

A PipelineRun can report **Succeeded** while **not** exercising OpenShift CI or
IQE. Common cases:

| Signal | Meaning |
|--------|---------|
| Completes in ~2–3 minutes with `provision-cluster` / `run-iqe-cost-operator` **skipped** | `selectedBundle` was empty (no unreleased bundle and no `RELEASED_BUNDLE_IMAGE_OVERRIDE`) — **not** a valid proof |
| Completes in ~10–30 seconds with most tasks skipped | Missing PipelineRun labels (`event-type`, application, component) so `parse-metadata` did not see a push/PR event |
| GitHub Konflux check: `No matching PipelineRun found…` | Expected for some path changes (see below) — **neutral**, not an IQE result |

Treat a run as valid only when **all** are true:

1. Duration is long (often 30–90+ minutes) — provision + IQE actually ran.
2. `provision-cluster` and `run-iqe-cost-operator` are **not** skipped.
3. `provision-cluster` used OpenShift CI / HyperShift on `aws-konflux-prod` (not EaaS).
4. `run-iqe-cost-operator` succeeded.

## When GitHub / ITS do not prove pipeline changes

Three gaps stack together when you change
[`.tekton/pipelines/deploy-fbc-operator-with-iqe.yaml`](pipelines/deploy-fbc-operator-with-iqe.yaml)
(or need a real proof without a usable unreleased bundle):

1. **Pipelines-as-Code may not match the PR** — PaC only starts a PipelineRun when
   a `.tekton/` file has `on-event` / path matchers for the GitHub event. Build
   `*-pull-request.yaml` files do not watch `.tekton/pipelines/**`. IQE files under
   `pipelineruns/` are Integration Test Scenario templates without PaC PR
   annotations. Result: a **neutral** GitHub check (`No matching PipelineRun…`).
2. **`/ok-to-test` and `/retest` re-run the same matcher** — they will not start
   the IQE pipeline if PaC never matched.
3. **ITS always resolves the pipeline from `main`** — a normal Integration Test
   Scenario retest loads `project-koku/.../main` +
   `.tekton/pipelines/deploy-fbc-operator-with-iqe.yaml`. That does **not**
   validate an unmerged PR branch.

In those cases, use the **manual proof PipelineRun** below.

## Manual proof workaround

Create a one-off PipelineRun in `cost-mgmt-dev-tenant` with `oc create -f`.
Start from a versioned template such as
[`.tekton/pipelineruns/deploy-fbc-operator-with-iqe-run-v4-19.yaml`](pipelineruns/deploy-fbc-operator-with-iqe-run-v4-19.yaml)
and override the fields below.

### Required overrides

| Field | Purpose |
|-------|---------|
| `metadata.name` | **Unique** name every time (reusing a name causes `TestPlatformCluster` `AlreadyExists` and stale UI logs) |
| `metadata.labels` | Must include application, component, and `pac.test.appstudio.openshift.io/event-type: push` (see below) |
| `pipelineRef` git `url` / `revision` | Pin the pipeline YAML you want to test (PR fork/branch, or `main` after merge) |
| `params.SNAPSHOT` | JSON of a **push** snapshot `.spec` only (catalog/FBC input) |
| `params.RELEASED_BUNDLE_IMAGE_OVERRIDE` | Operator bundle image when `get-unreleased-bundle` finds nothing |

### Required PipelineRun labels

`parse-metadata` reads labels on the **PipelineRun** (downward API), not labels
inside the SNAPSHOT JSON:

```yaml
metadata:
  labels:
    appstudio.openshift.io/application: costmanagement-metrics-operator-fbc-v4-19
    appstudio.openshift.io/component: costmanagement-metrics-operator-fbc-component-v4-19
    pac.test.appstudio.openshift.io/event-type: push
```

Adjust the application/component names for the OCP version under test.
Without these labels, the pipeline “succeeds” in seconds by skipping provision and IQE.

### SNAPSHOT format

Use **only** the snapshot `.spec` as the `SNAPSHOT` param value:

```sh
oc get snapshot <SNAPSHOT_NAME> -o jsonpath='{.spec}'
```

Do **not** pass `{metadata:…, spec:…}`. `parse-metadata` expects `.components[]` at the root.

### Bundle override

If `get-unreleased-bundle` logs that no unreleased bundles were found,
`select-bundle-image` leaves `selectedBundle` empty and `provision-cluster` is
skipped. Set `RELEASED_BUNDLE_IMAGE_OVERRIDE` to a recent operator bundle from
the tenant:

```sh
oc get snapshots -l appstudio.openshift.io/component=costmanagement-metrics-operator-bundle \
  --sort-by=.metadata.creationTimestamp | tail -3

oc get snapshot <NAME> -o jsonpath='{.spec.components[0].containerImage}{"\n"}'
```

### Example skeleton

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  # Use a unique name per attempt
  name: prove-fbc-iqe-yaml-v4-19-<unique-suffix>
  labels:
    upstream-usable: "true"
    appstudio.openshift.io/application: costmanagement-metrics-operator-fbc-v4-19
    appstudio.openshift.io/component: costmanagement-metrics-operator-fbc-component-v4-19
    pac.test.appstudio.openshift.io/event-type: push
  annotations:
    pac.test.appstudio.openshift.io/repo-url: https://github.com/project-koku/cost-management-metrics-operator-fbc
    pac.test.appstudio.openshift.io/branch: main
spec:
  pipelineRef:
    resolver: git
    params:
      - name: url
        # Fork URL when proving a PR; project-koku URL when proving main
        value: https://github.com/project-koku/cost-management-metrics-operator-fbc.git
      - name: revision
        value: main
      - name: pathInRepo
        value: .tekton/pipelines/deploy-fbc-operator-with-iqe.yaml
  params:
    - name: SNAPSHOT
      value: '<paste output of: oc get snapshot <name> -o jsonpath="{.spec}">'
    - name: RELEASED_BUNDLE_IMAGE_OVERRIDE
      value: '<bundle image@sha256:… when needed>'
  timeouts:
    pipeline: "2h30m0s"
  taskRunTemplate:
    serviceAccountName: build-pipeline-costmanagement-metrics-operator-fbc-component-v4-19
  workspaces:
    - name: shared-data
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 1Gi
```

### How to run

```sh
oc login --token=<from-console> --server=https://api.stone-prd-rh01.pg1f.p1.openshiftapps.com:6443
oc project cost-mgmt-dev-tenant

# Prefer a new unique metadata.name. If you must reuse a name:
oc delete pipelinerun <name>
oc wait --for=delete pipelinerun/<name> --timeout=120s

oc create -f /path/to/proof-pipelinerun.yaml
oc get pipelinerun <name> -w
```

Watch in Konflux UI under the matching FBC application in `cost-mgmt-dev-tenant`.

### Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Completes in ~10s, many tasks skipped | Missing PipelineRun labels | Add `event-type` / application / component labels; recreate with a **new** name |
| `jq: Cannot iterate over null` in `parse-metadata` | SNAPSHOT wrapped in `metadata`+`spec` | Use `.spec` only |
| `provision-cluster` skipped | Empty `selectedBundle` | Set `RELEASED_BUNDLE_IMAGE_OVERRIDE` or use a push snapshot with an unreleased bundle |
| `TestPlatformCluster` `AlreadyExists` | Reused PipelineRun name / leftover claim | Unique `metadata.name`; delete old PipelineRun and wait |
| GitHub check still neutral after a green proof | PaC never matched PR paths | Expected; merge gate is the manual proof, not the PR check |
| ITS retest does not exercise the PR branch | ITS resolves pipeline from `main` | Pin `pipelineRef` to the PR fork/revision |

### Optional: trigger a normal ITS (main only)

After the pipeline change is on `main`, you can also label a suitable **push**
snapshot so Konflux creates the usual `deploy-fbc-operator-with-iqe-run-v4-XX-*`
PipelineRun. Prefer a snapshot that can resolve a bundle (or accept that you must
use the manual override path above). Do not fire all OCP versions at once —
`aws-konflux-prod` leases are shared.

## IQE prerequisites

IQE automation in this pipeline has two required access dependencies:

- **Vault access:** the IQE run uses Vault-backed configuration and reads
  `DYNACONF_IQE_VAULT_SECRET_ID` from secret `cost-mgmt-vault-ci-secret`.
  Ensure the namespace has this secret and that `DYNACONF_IQE_VAULT_ROLE_ID`
  is set for the run when Vault loader is enabled.
- **IQE image pull secret/access:** default IQE image is
  `quay.io/cloudservices/iqe-tests:cost-management`. The PipelineRun service
  account must be able to pull this image (for example through configured pull
  credentials/imagePullSecrets), or the `verify-iqe-image-access`/`run-iqe`
  steps will fail.

## Tasks

This repository currently defines one local task:

- [`.tekton/tasks/run-iqe-cost-operator.yaml`](tasks/run-iqe-cost-operator.yaml)

Add new repo-owned tasks under `tasks/` as the flow expands.

The pipeline also references upstream tasks/step actions through git resolvers
(for example metadata parsing, OpenShift CI provision, and credentials retrieval)
from the repositories listed above.

## Pipelines

This repository currently defines one integration pipeline:

- [`.tekton/pipelines/deploy-fbc-operator-with-iqe.yaml`](pipelines/deploy-fbc-operator-with-iqe.yaml)

Add new repo-owned pipelines under `pipelines/` as needed.

Use this file as the source of truth for task ordering, params contract, and
how upstream and local tasks are composed.

## PipelineRuns

PipelineRun definitions live in:

- [`.tekton/pipelineruns/README.md`](pipelineruns/README.md)

Shared PipelineRun configuration is maintained in:

- [`.tekton/pipelineruns/deploy-fbc-operator-with-iqe-run-template.yaml`](pipelineruns/deploy-fbc-operator-with-iqe-run-template.yaml)

Generated outputs:

- `.tekton/pipelineruns/deploy-fbc-operator-with-iqe-run-v*.yaml`

Renderer script:

- [`.tekton/pipelineruns/render-pipelineruns.sh`](pipelineruns/render-pipelineruns.sh)

## Update workflow

When changing shared PipelineRun behavior:

1. Edit the template file.
2. Run `bash .tekton/pipelineruns/render-pipelineruns.sh`.
3. Review generated `deploy-fbc-operator-with-iqe-run-v*.yaml` outputs.
4. Commit template + regenerated files together.

## Usage notes

- Keep only version-specific differences in rendered files.
- If support changes (add/remove OCP versions), update `VERSIONS` in
  `render-pipelineruns.sh` and rerender.

## Related

- [COST-8250](https://redhat.atlassian.net/browse/COST-8250) — EaaS → OpenShift CI migration (IQE)
- [COST-8319](https://redhat.atlassian.net/browse/COST-8319) — document / harden CI signals after COST-8250
- Team pointer (internal): Cost Management `service-docs` → CMMO FBC IQE manual proof
