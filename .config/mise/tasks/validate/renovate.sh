#!/usr/bin/env bash
#MISE description="Validate .github/renovate.json5 via renovate-config-validator"
#MISE sources=[".github/renovate.json5", ".github/workflows/renovate.yml"]
#MISE tools="node"
#
# Env vars: RENOVATE_VERSION (default: latest)

set -euxo pipefail

npm install -g "renovate@${RENOVATE_VERSION:-latest}"
renovate-config-validator --strict
