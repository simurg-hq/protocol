#!/usr/bin/env bash
#
# Fails when the pull request weakens existing tests: a removed or changed
# assertion line (which includes a changed expected value) or an added skip.
# New test files, new tests and new assertions are always allowed.
#
# A human can allow a deliberate change with the tests-change-approved label;
# CI then sets TESTS_CHANGE_APPROVED=true.
#
# Usage: test-tampering.sh <base> [head]
# The same script is copied to every repository, so it knows the test files
# and assertion styles of all of them: Pest/PHPUnit, Go, bats, Terraform tests
# and TypeScript tests. Patterns avoid backslashes so awk -v keeps them as is.

set -euo pipefail

readonly TEST_FILE='(^|/)tests/.*[.]php$|_test[.]go$|[.]bats$|[.]tftest[.]hcl$|[.](test|spec)[.]ts$'
# Expectations and assertions (Pest, PHPUnit, Laravel), Go failures and
# expected values (want/expected), testify, bats-assert, Terraform test asserts.
readonly ASSERTION='expect[[:space:]]*[(]|->(not->)?to[A-Z]|->assert[A-Z]|(^|[^A-Za-z0-9_$>])assert[A-Z][A-Za-z]*[[:space:]]*[(]|(this|self|static)(->|::)assert|t[.](Error|Errorf|Fatal|Fatalf|Fail|FailNow)[(]|(require|assert)[.][A-Z]|(^|[^A-Za-z0-9_])(want|expected)[A-Za-z0-9_]*|(^|[^A-Za-z0-9_])(assert|refute)(_[a-z_]+)?([[:space:]]|$)|^[[:space:]]*condition[[:space:]]*='
# Pest skip/todo/only modifiers, PHPUnit, Go, TypeScript, bats.
readonly SKIP='->(skip[A-Za-z]*|todo|only)[[:space:]]*[(]|markTest(Skipped|Incomplete)|t[.](Skip|Skipf|SkipNow)[(]|(it|test|describe)[.](skip|only|todo)[(]|^[[:space:]]*skip([[:space:]]|$)'

base=${1:?usage: test-tampering.sh <base> [head]}
head=${2:-HEAD}

for rev in "$base" "$head"; do
    if ! git rev-parse --quiet --verify "$rev^{commit}" >/dev/null; then
        echo "test-tampering: unknown revision '$rev'" >&2
        exit 2
    fi
done

if [[ ${TESTS_CHANGE_APPROVED:-} == true ]]; then
    level=warning
else
    level=error
fi

# Reads a zero-context diff and prints one annotation per finding. Removed
# lines are reported with their line number in the base, because they no
# longer exist in the head.
scan_diff() {
    awk -v test_file="$TEST_FILE" -v assertion="$ASSERTION" -v skip="$SKIP" -v level="$level" '
        function code(line) { line = substr(line, 2); sub(/^[[:space:]]+/, "", line); return line }
        # File headers come only between "diff --git" and the first hunk.
        /^diff --git / { header = 1; is_test = 0; old = ""; next }
        header && /^--- / { old = substr($0, 5); sub("^a/", "", old); next }
        header && /^[+][+][+] / {
            new = substr($0, 5); sub("^b/", "", new)
            path = (new == "/dev/null") ? old : new
            is_test = path ~ test_file
            next
        }
        /^@@ / {
            header = 0
            split($2, o, ","); old_line = substr(o[1], 2)
            split($3, n, ","); new_line = substr(n[1], 2)
            next
        }
        is_test && /^-/ {
            if (old != "/dev/null" && substr($0, 2) ~ assertion)
                printf "::%s file=%s::Assertion removed or changed (base line %d): %s\n", level, path, old_line, code($0)
            old_line++
            next
        }
        is_test && /^[+]/ {
            if (old != "/dev/null" && substr($0, 2) ~ skip)
                printf "::%s file=%s,line=%d::Skip added: %s\n", level, path, new_line, code($0)
            new_line++
        }
    '
}

findings=$(git diff --no-color --no-ext-diff --unified=0 -M --src-prefix=a/ --dst-prefix=b/ "$base...$head" | scan_diff)

if [[ -z $findings ]]; then
    echo "No assertions removed or changed and no skips added in existing tests."
    exit 0
fi
echo "$findings"
count=$(wc -l <<<"$findings")
if [[ $level == warning ]]; then
    echo "::notice::$count test change(s) allowed by the tests-change-approved label set by a human."
    exit 0
fi
echo "::error::$count test change(s) weaken existing tests. Fix the code instead, or ask a human to add the tests-change-approved label for a deliberate change."
exit 1
