# Historical Spec: CMMO FBC Konflux IQE Integration

> Historical planning doc; current operational docs are in
> [`.tekton/README.md`](../../.tekton/README.md).

## Implementation status

This initiative is implemented in-repo and is no longer only a proposal.
Current source-of-truth operational docs and asset layout live under `.tekton/`.

Implemented repository assets:

- Pipeline: [`.tekton/pipelines/deploy-fbc-operator-with-iqe.yaml`](../../.tekton/pipelines/deploy-fbc-operator-with-iqe.yaml)
- Custom task: [`.tekton/tasks/run-iqe-cost-operator.yaml`](../../.tekton/tasks/run-iqe-cost-operator.yaml)
- PipelineRun template:
  [`.tekton/pipelineruns/deploy-fbc-operator-with-iqe-run-template.yaml`](../../.tekton/pipelineruns/deploy-fbc-operator-with-iqe-run-template.yaml)
- Generated PipelineRuns:
  `deploy-fbc-operator-with-iqe-run-v*.yaml`

Upstream baseline reference:

- [deploy-fbc-operator (tekton-integration-catalog)](https://github.com/konflux-ci/tekton-integration-catalog/tree/main/pipelines/deploy-fbc-operator)

## Finalized architecture summary

The local integration pipeline preserves upstream `deploy-fbc-operator` baseline
deployment behavior and inserts IQE execution in the post-deploy stage.

Current high-level flow:

1. Parse metadata and provision test infrastructure.
2. Resolve bundle/package/channel and mirror-set configuration.
3. Provision ephemeral cluster and deploy the operator.
4. Run IQE operator coverage (`cost_management` plugin / `cost_operator`
   marker by default).
5. Run final verification and completion checks.

## Finalized defaults and behavior

- Default channel: `stable`.
- IQE plugin default: `cost_management`.
- IQE marker default: `cost_operator`.
- Push/merge path remains the primary execution model.
- Unsupported OCP target behavior follows upstream selection/fallback policy.
- Artifact publishing remains part of the integration flow and can fail the run.

## Why this document is archived

This file captures planning intent and implementation decisions made during the
initial integration design phase. Day-to-day usage, troubleshooting, and update
procedures are maintained in `.tekton` docs next to the actual Tekton assets.
