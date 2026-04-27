# Tekton CI Documentation

This directory contains repository-owned Tekton assets for CI execution,
including build definitions, pull-request/push triggers, pipelines, tasks, and
versioned PipelineRuns.

## Architecture and upstream baseline

The local integration pipeline is:

- [`.tekton/pipelines/deploy-fbc-operator-with-iqe.yaml`](pipelines/deploy-fbc-operator-with-iqe.yaml)

It extends the upstream `deploy-fbc-operator` behavior by preserving the
baseline deploy sequence and adding IQE execution after operator deployment.
Upstream baseline references:

- [Konflux integration examples repository](https://github.com/konflux-ci/integration-examples)
- [Shared build definitions repository](https://github.com/konflux-ci/build-definitions)
- [Upstream deploy-fbc-operator pipeline](https://github.com/konflux-ci/tekton-integration-catalog/tree/main/pipelines/deploy-fbc-operator)
- [Tekton integration catalog repository](https://github.com/konflux-ci/tekton-integration-catalog)

Current high-level runtime flow:

1. Deploy the FBC operator on an ephemeral cluster.
2. Run IQE operator coverage.
3. Run final verification checks (for example image-source validation).

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
(for example metadata parsing, EaaS provision, and credentials retrieval) from
the repositories listed above.

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
