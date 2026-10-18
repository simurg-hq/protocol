# AGENTS.md

Instructions for coding agents and humans working in this repository.

## Purpose

`protocol` defines the ping protocol in one place:

- `SPEC.md`: the HTTP ping protocol and the event schema, versioned.
- `fixtures/`: shared JSON contract fixtures (request → expected response and event). Every client and server implementation is tested against them.
- A Go reference package with the event types and a fixture loader.

This repository is public and MIT licensed. It must stay self-contained: do
not reference private repositories or internal documents.

## Repository layout

| Path | Contents |
| --- | --- |
| `SPEC.md` | Protocol specification. |
| `fixtures/v1/` | Fixtures for protocol version 1. |
| `schema/` | JSON Schemas that fixtures and events are validated against. |
| `*.go` | Go package `protocol` (module `github.com/simurg-hq/protocol`). |
| `scripts/ci/` | CI helper scripts and their tests. |

Some of these paths are created by later tasks; keep to this layout when you
add them.

## Naming

- Standard Go conventions, formatted with `gofmt`. Exported identifiers have doc comments.
- JSON field names are `snake_case`. Fixture files are named `<nnn>-<behavior>.json`, for example `001-start.json`.

## Rules

- The protocol is a contract. Within a version, changes are additive only: never change the meaning of an existing field or fixture. A breaking change needs a new version directory.
- Every change to `SPEC.md` comes with fixtures that exercise it.
- One task, one branch, one pull request against `main`. Keep the diff outside tests, fixtures and generated files under 400 lines; if it will not fit, stop and ask for the task to be split.
- Never merge a pull request, push to `main`, or add or remove labels. A human merges, and the approval labels (`size-approved`, `tests-change-approved`) are a human's decision. Branch protection blocks merging a red pull request, but nothing on GitHub stops an agent from merging a green one or changing labels, so it is on you.
- Touch only the files your task needs. If it needs files outside its scope, stop and ask for the task to be re-planned.
- Write the failing test first. Every acceptance criterion maps to at least one test.
- Implement only what the task asks for.
- Standard library only unless a dependency is clearly justified in the pull request.
- Never lower a threshold, disable or skip a check, delete or weaken a test, or add an ignore comment, suppression or baseline to make a gate pass. Such a change needs its own pull request approved by a human.
- Do not change `.github/`, `AGENTS.md`, `CLAUDE.md`, `.golangci.yml` or test thresholds unless the task is explicitly about them.
- Never hardcode the product name in user-facing text; if the Go package needs it, define it once as a constant and use that constant.
- Never create or commit secrets, tokens or real credentials. Fixture tokens are obviously fake values.
- Code, comments, commit messages and documents are in English.
- Commit messages use a type prefix: `feat`, `fix`, `test`, `refactor`, `docs`, `ci`, `chore`.

## Quality gates

Every gate runs in Docker through `make`; nothing but Docker and Lefthook is
needed on the host. Run the gates before pushing and show their output as
evidence. "It should work" is not evidence.

```sh
make help               # list all targets
make secrets-staged     # gitleaks over the staged changes (pre-commit hook)
make lint-ci-scripts    # shellcheck for scripts/ci
make test-ci-scripts    # bats tests for scripts/ci
make pr-size            # measure this branch against origin/main
make test-tampering     # assertions removed or changed and skips added in tests since origin/main
make validate-schemas   # JSON Schemas, fixtures and schema test samples
make check              # all Go gates below
make fmt-check          # gofmt
make lint               # golangci-lint (.golangci.yml)
make test               # go test -race
make vulncheck          # govulncheck
make secrets            # gitleaks over the git history
```

The Go tests validate every fixture against the schemas, so a fixture change
also runs `make test`.

A schema change comes with samples in `schema/testdata/*/valid` and
`schema/testdata/*/invalid` that show what it accepts and rejects.

`lefthook.yml` runs the format, static analysis and secret checks on commit,
each only when a matching file is staged; enable it once per clone with
`lefthook install`. Tests are not part of the hooks; CI runs them on every pull
request. Never skip the hooks with `--no-verify`.

A task that adds a gate also adds its `make` target and lists it here.

## When you are stuck

1. If the same gate fails three times, do not weaken the test or the gate.
2. Hand the task to the next implementer tier.
3. If the top tier also fails three times on the same gate, stop and write a blocker note: which gate failed, the exact error, what was tried and why it did not work.

## Definition of done

The checklist in `.github/pull_request_template.md` must be complete before a
pull request is merged.
