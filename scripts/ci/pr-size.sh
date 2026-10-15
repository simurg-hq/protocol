#!/usr/bin/env bash
#
# Measures the size of a pull request, excluding tests and generated files.
# Warns above WARN_LINES and fails above FAIL_LINES changed lines.
#
# A human can allow an oversized PR (e.g. an unmodified framework scaffold)
# with the size-approved label; CI then sets PR_SIZE_APPROVED=true.
#
# Usage: pr-size.sh <base> [head]
# Exclude patterns are read from .github/pr-size-exclude (one glob per line,
# '#' starts a comment). A '*' in a pattern also matches '/'.

set -euo pipefail

readonly WARN_LINES=400
readonly FAIL_LINES=800
readonly EXCLUDE_FILE=.github/pr-size-exclude

base=${1:?usage: pr-size.sh <base> [head]}
head=${2:-HEAD}

for rev in "$base" "$head"; do
    if ! git rev-parse --quiet --verify "$rev^{commit}" >/dev/null; then
        echo "pr-size: unknown revision '$rev'" >&2
        exit 2
    fi
done

# Globs are converted to anchored regular expressions: '*' becomes '.*',
# '?' becomes '.', and every other regex metacharacter is matched literally.
glob_to_regex() {
    local escaped
    escaped=$(sed -e 's/[].[^$+(){}|\\]/\\&/g' -e 's/\*/.*/g' -e 's/?/./g' <<<"$1")
    printf '^%s$' "$escaped"
}

patterns=()
if [[ -f $EXCLUDE_FILE ]]; then
    while IFS= read -r line || [[ -n $line ]]; do
        line=${line%%#*}
        read -r line <<<"$line"
        if [[ -n $line ]]; then
            patterns+=("$(glob_to_regex "$line")")
        fi
    done <"$EXCLUDE_FILE"
fi

is_excluded() {
    local pattern
    for pattern in "${patterns[@]}"; do
        if [[ $1 =~ $pattern ]]; then
            return 0
        fi
    done
    return 1
}

counted=0
excluded=0

# With -z, a rename is reported as "added<TAB>deleted<TAB>" followed by the
# old and new paths as separate NUL-terminated fields.
while IFS= read -r -d '' entry; do
    IFS=$'\t' read -r added deleted path <<<"$entry"
    if [[ -z $path ]]; then
        IFS= read -r -d '' _
        IFS= read -r -d '' path
    fi
    if [[ $added == - ]]; then
        continue
    fi
    if is_excluded "$path"; then
        excluded=$((excluded + added + deleted))
    else
        counted=$((counted + added + deleted))
    fi
done < <(git diff --numstat -z -M "$base...$head")

summary="PR size: $counted lines counted, $excluded excluded (tests and generated files). Warning above $WARN_LINES, failure above $FAIL_LINES."
echo "$summary"
if [[ -n ${GITHUB_STEP_SUMMARY:-} ]]; then
    echo "$summary" >>"$GITHUB_STEP_SUMMARY"
fi

if ((counted > FAIL_LINES)) && [[ ${PR_SIZE_APPROVED:-} == true ]]; then
    echo "::notice::This PR changes $counted lines (limit $FAIL_LINES) but carries the size-approved label set by a human."
    exit 0
fi
if ((counted > FAIL_LINES)); then
    echo "::error::This PR changes $counted lines outside tests and generated files (limit $FAIL_LINES). Split the task."
    exit 1
fi
if ((counted > WARN_LINES)); then
    echo "::warning::This PR changes $counted lines outside tests and generated files (target $WARN_LINES)."
fi
