#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

if ! command -v rojo >/dev/null 2>&1; then
    printf 'Error: rojo was not found in PATH.\n' >&2
    printf 'Run this through Aftman or add Rojo to PATH, then try again.\n' >&2
    exit 127
fi

project_count=0
success_count=0
failure_count=0

while IFS= read -r -d '' project_file; do
    project_dir="$(dirname -- "$project_file")"
    sourcemap_file="$project_dir/sourcemap.json"
    project_count=$((project_count + 1))

    printf 'Generating %s\n' "${project_dir#"$REPO_ROOT/"}"
    if (
        cd -- "$project_dir" &&
        rojo sourcemap "$(basename -- "$project_file")" -o "$sourcemap_file"
    ); then
        success_count=$((success_count + 1))
    else
        failure_count=$((failure_count + 1))
        printf 'Failed: %s\n' "${project_dir#"$REPO_ROOT/"}" >&2
    fi
done < <(find "$REPO_ROOT" -type f -name 'default.project.json' -not -path '*/.git/*' -print0 | sort -z)

if [[ $project_count -eq 0 ]]; then
    printf 'No default.project.json files found under %s\n' "$REPO_ROOT" >&2
    exit 1
fi

printf '\nGenerated %d/%d sourcemap(s).\n' "$success_count" "$project_count"

if [[ $failure_count -gt 0 ]]; then
    exit 1
fi
