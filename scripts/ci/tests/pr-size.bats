#!/usr/bin/env bats

load '/usr/lib/bats/bats-support/load'
load '/usr/lib/bats/bats-assert/load'

SCRIPT="$BATS_TEST_DIRNAME/../pr-size.sh"

setup() {
    unset PR_SIZE_APPROVED GITHUB_STEP_SUMMARY
    cd "$BATS_TEST_TMPDIR"
    git init -q -b main repo
    cd repo
    git config user.email test@example.com
    git config user.name test
    mkdir -p .github
    printf '%s\n' '# Tests' 'tests/*' '' 'composer.lock  # generated' > .github/pr-size-exclude
    echo base > base.txt
    git add -A
    git commit -q -m base
    git switch -q -c feature
}

write_lines() {
    mkdir -p "$(dirname "$1")"
    seq 1 "$2" > "$1"
}

commit_all() {
    git add -A
    git commit -q -m change
}

@test "passes at the warning threshold" {
    write_lines src/a.txt 400
    commit_all

    run "$SCRIPT" main

    assert_success
    assert_output --partial "400 lines counted"
    refute_output --partial "::warning::"
}

@test "warns above 400 counted lines" {
    write_lines src/a.txt 401
    commit_all

    run "$SCRIPT" main

    assert_success
    assert_output --partial "::warning::"
}

@test "fails above 800 counted lines" {
    write_lines src/a.txt 801
    commit_all

    run "$SCRIPT" main

    assert_failure 1
    assert_output --partial "::error::"
}

@test "does not count files matching exclude patterns" {
    write_lines tests/Feature/a.txt 900
    write_lines composer.lock 900
    write_lines src/a.txt 10
    commit_all

    run "$SCRIPT" main

    assert_success
    assert_output --partial "10 lines counted"
    assert_output --partial "1800 excluded"
}

@test "matches regex metacharacters in patterns literally" {
    printf '%s\n' 'a.b' > .github/pr-size-exclude
    write_lines axb 801
    commit_all

    run "$SCRIPT" main

    assert_failure 1
}

@test "counts deleted lines" {
    git switch -q main
    write_lines src/big.txt 801
    commit_all
    git switch -q -c removal
    git rm -q src/big.txt
    commit_all

    run "$SCRIPT" main

    assert_failure 1
}

@test "counts only changed lines of a renamed file" {
    git switch -q main
    write_lines src/old.txt 900
    commit_all
    git switch -q -c rename
    git mv src/old.txt src/new.txt
    commit_all

    run "$SCRIPT" main

    assert_success
    assert_output --partial "0 lines counted"
}

@test "ignores binary files" {
    head -c 4096 /dev/urandom > image.bin
    commit_all

    run "$SCRIPT" main

    assert_success
    assert_output --partial "0 lines counted"
}

@test "writes the result to the step summary when available" {
    write_lines src/a.txt 5
    commit_all
    export GITHUB_STEP_SUMMARY="$BATS_TEST_TMPDIR/summary.md"

    run "$SCRIPT" main

    assert_success
    run cat "$GITHUB_STEP_SUMMARY"
    assert_output --partial "5 lines counted"
}

@test "exits with usage error for an unknown base" {
    run "$SCRIPT" does-not-exist

    assert_failure 2
    assert_output --partial "unknown revision"
}

@test "passes above 800 lines when the PR is size-approved" {
    write_lines src/a.txt 801
    commit_all
    export PR_SIZE_APPROVED=true

    run "$SCRIPT" main

    assert_success
    assert_output --partial "::notice::"
    assert_output --partial "size-approved"
}

@test "treats any value other than true as not approved" {
    write_lines src/a.txt 801
    commit_all
    export PR_SIZE_APPROVED=yes

    run "$SCRIPT" main

    assert_failure 1
}
