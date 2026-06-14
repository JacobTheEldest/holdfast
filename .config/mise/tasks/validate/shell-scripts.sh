#!/usr/bin/env bash
#MISE description="Run shellcheck on build/*.sh and the mise task scripts"
#MISE sources=["build/**/*.sh", ".config/mise/tasks/**/*.sh"]
#MISE tools="shellcheck"

set -euxo pipefail

echo "Running shellcheck on build/ and .config/mise/tasks/ scripts..."

find build .config/mise/tasks -iname '*.sh' -print0 | while IFS= read -r -d '' script; do
    echo "::group:: ===$(basename "$script")==="
    shellcheck -x "$script"
    echo "✓ $script passed shellcheck"
    echo "::endgroup::"
done

echo "All shell scripts passed validation"
