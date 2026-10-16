#!/usr/bin/env bats

load '/usr/lib/bats/bats-support/load'
load '/usr/lib/bats/bats-assert/load'

SCRIPT="$BATS_TEST_DIRNAME/../test-tampering.sh"

setup() {
    unset TESTS_CHANGE_APPROVED
    cd "$BATS_TEST_TMPDIR"
    git init -q -b main repo
    cd repo
    git config user.email test@example.com
    git config user.name test
    mkdir -p tests/Feature internal scripts/ci/tests src
    cat > tests/Feature/RunTest.php <<'EOF'
<?php

it('marks the run as failed', function () {
    $run = finishRun(exitCode: 1);

    expect($run->status)->toBe('failed');
    $this->get('/runs')->assertOk();
});
EOF
    cat > internal/run_test.go <<'EOF'
package internal

import "testing"

func TestStatus(t *testing.T) {
	got, want := status(1), "failed"
	if got != want {
		t.Errorf("status() = %q, want %q", got, want)
	}
}
EOF
    cat > scripts/ci/tests/tool.bats <<'EOF'
@test "tool succeeds" {
    run tool
    assert_success
}
EOF
    echo '<?php' > src/Run.php
    git add -A
    git commit -q -m base
    git switch -q -c feature
}

commit_all() {
    git add -A
    git commit -q -m change
}

# replace <file> <old> <new>: literal, first occurrence.
replace() {
    local content
    content=$(<"$1")
    printf '%s\n' "${content/"$2"/"$3"}" > "$1"
}

@test "passes when only code changed" {
    echo '// change' >> src/Run.php
    commit_all

    run "$SCRIPT" main

    assert_success
    assert_output --partial "No assertions removed or changed and no skips added"
}

@test "passes when tests and assertions are added" {
    cat >> tests/Feature/RunTest.php <<'EOF'

it('marks the run as finished', function () {
    expect(finishRun(exitCode: 0)->status)->toBe('success');
});
EOF
    cat > tests/Feature/NewTest.php <<'EOF'
<?php

it('works', fn () => expect(true)->toBeTrue());
EOF
    commit_all

    run "$SCRIPT" main

    assert_success
}

@test "fails when a Pest assertion is removed" {
    replace tests/Feature/RunTest.php "    expect(\$run->status)->toBe('failed');" ""
    commit_all

    run "$SCRIPT" main

    assert_failure 1
    assert_output --partial "::error file=tests/Feature/RunTest.php::Assertion removed or changed (base line 6): expect(\$run->status)->toBe('failed');"
}

@test "fails when an expected value changes" {
    replace tests/Feature/RunTest.php "toBe('failed')" "toBe('success')"
    commit_all

    run "$SCRIPT" main

    assert_failure 1
    assert_output --partial "Assertion removed or changed (base line 6)"
}

@test "fails when a Laravel response assertion is removed" {
    replace tests/Feature/RunTest.php "    \$this->get('/runs')->assertOk();" "    \$this->get('/runs');"
    commit_all

    run "$SCRIPT" main

    assert_failure 1
    assert_output --partial "(base line 7)"
}

@test "fails when a Go expected value changes" {
    replace internal/run_test.go '"failed"' '"success"'
    commit_all

    run "$SCRIPT" main

    assert_failure 1
    assert_output --partial "::error file=internal/run_test.go::Assertion removed or changed (base line 6)"
}

@test "fails when a Go failure call is removed" {
    replace internal/run_test.go '		t.Errorf("status() = %q, want %q", got, want)' ''
    commit_all

    run "$SCRIPT" main

    assert_failure 1
    assert_output --partial "(base line 8)"
}

@test "fails when a bats assertion is removed" {
    replace scripts/ci/tests/tool.bats "    assert_success" ""
    commit_all

    run "$SCRIPT" main

    assert_failure 1
    assert_output --partial "file=scripts/ci/tests/tool.bats"
}

@test "fails when a test file is deleted" {
    git rm -q tests/Feature/RunTest.php
    commit_all

    run "$SCRIPT" main

    assert_failure 1
    assert_output --partial "file=tests/Feature/RunTest.php"
}

@test "checks only changed lines of a renamed test file" {
    git mv tests/Feature/RunTest.php tests/Feature/RunStatusTest.php
    commit_all

    run "$SCRIPT" main

    assert_success
}

@test "fails when a Pest test is skipped" {
    replace tests/Feature/RunTest.php "});" "})->skip();"
    commit_all

    run "$SCRIPT" main

    assert_failure 1
    assert_output --partial "::error file=tests/Feature/RunTest.php,line=8::Skip added: })->skip();"
}

@test "fails when a Go test is skipped" {
    replace internal/run_test.go "	got, want" "	t.Skip(\"later\")
	got, want"
    commit_all

    run "$SCRIPT" main

    assert_failure 1
    assert_output --partial "Skip added: t.Skip(\"later\")"
}

@test "fails when a bats test is skipped" {
    replace scripts/ci/tests/tool.bats "    run tool" "    skip
    run tool"
    commit_all

    run "$SCRIPT" main

    assert_failure 1
    assert_output --partial "Skip added: skip"
}

@test "allows skips in a new test file" {
    cat > tests/Feature/NewTest.php <<'EOF'
<?php

it('works', fn () => expect(true)->toBeTrue())->skip();
EOF
    commit_all

    run "$SCRIPT" main

    assert_success
}

@test "ignores assertion-like lines outside test files" {
    echo "expect(\$x)->toBe(1);" > src/Run.php
    commit_all
    echo '<?php' > src/Run.php
    commit_all

    run "$SCRIPT" main

    assert_success
}

@test "passes with a warning when the change is approved by a human" {
    replace tests/Feature/RunTest.php "toBe('failed')" "toBe('success')"
    commit_all

    TESTS_CHANGE_APPROVED=true run "$SCRIPT" main

    assert_success
    assert_output --partial "::warning file=tests/Feature/RunTest.php::"
    assert_output --partial "allowed by the tests-change-approved label"
}

@test "treats any value other than true as not approved" {
    replace tests/Feature/RunTest.php "toBe('failed')" "toBe('success')"
    commit_all

    TESTS_CHANGE_APPROVED=yes run "$SCRIPT" main

    assert_failure 1
}

@test "exits with usage error for an unknown base" {
    run "$SCRIPT" no-such-branch

    assert_failure 2
    assert_output --partial "unknown revision"
}
