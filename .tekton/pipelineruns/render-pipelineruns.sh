#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${SCRIPT_DIR}/deploy-fbc-operator-with-iqe-run-template.yaml"

if [[ ! -f "${TEMPLATE}" ]]; then
  echo "Template not found: ${TEMPLATE}" >&2
  exit 1
fi

VERSIONS=(
  "4.20"
  "4.19"
  "4.18"
  "4.17"
  "4.16"
  "4.15"
  "4.14"
)

for version in "${VERSIONS[@]}"; do
  version_dash="${version//./-}"
  out="${SCRIPT_DIR}/deploy-fbc-operator-with-iqe-run-v${version_dash}.yaml"
  sed "s/__VERSION_DASH__/${version_dash}/g" "${TEMPLATE}" > "${out}"
  echo "Rendered ${out}"
done
