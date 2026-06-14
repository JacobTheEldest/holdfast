#!/usr/bin/env bash
#MISE description="Validate Justfile and custom/ujust/*.just formatting"
#MISE sources=["Justfile", "custom/ujust/**/*.just"]
#MISE tools="just"

set -euxo pipefail

echo "Validating justfiles in custom/ujust/ directory..."
echo "::group:: Validating Justfile"
just --unstable --fmt --check -f Justfile
echo "::endgroup::"
find "custom/ujust" -iname '*.just' -print0 | while IFS= read -r -d '' justfile; do
    echo "::group:: ===$(basename "$justfile")==="
    just --unstable --fmt --check -f "$justfile"
    echo "::endgroup::"
done
echo "All justfiles are valid"
