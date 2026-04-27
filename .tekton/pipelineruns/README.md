# PipelineRun Rendering

This directory stores generated version-specific PipelineRuns for
`deploy-fbc-operator-with-iqe`.

For architecture and end-to-end flow documentation, see:

- [`.tekton/README.md`](.tekton/README.md)

## Source of truth

Shared PipelineRun configuration is maintained in:

- `deploy-fbc-operator-with-iqe-run-template.yaml`

Generated outputs:

- `deploy-fbc-operator-with-iqe-run-v*.yaml`

## Render files

```bash
bash .tekton/pipelineruns/render-pipelineruns.sh
```

## Workflow

1. Edit `deploy-fbc-operator-with-iqe-run-template.yaml`.
2. Run `render-pipelineruns.sh`.
3. Commit both the template and regenerated `deploy-fbc-operator-with-iqe-run-v*.yaml`.
