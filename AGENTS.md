# AGENTS.md

Project knowledge for coding agents and humans working in this repository.

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
| `scripts/ci/` | Project scripts (schema validation). |

## Naming

- Standard Go conventions, formatted with `gofmt`. Exported identifiers have doc comments.
- JSON field names are `snake_case`. Fixture files are named `<nnn>-<behavior>.json`, for example `001-start.json`.

## Rules

- The protocol is a contract. Within a version, changes are additive only: never change the meaning of an existing field or fixture. A breaking change needs a new version directory.
- Every change to `SPEC.md` comes with fixtures that exercise it.
- Consumers pin this module by tag. A merged change to `SPEC.md`, `schema/` or `fixtures/` is released as a new `v0.x.0` tag by a maintainer, and each consumer then updates its `go.mod` to that tag.
- Standard library only unless a dependency is clearly justified in the pull request.
- Never hardcode the product name in user-facing text; if the Go package needs it, define it once as a constant and use that constant.
- Never create or commit secrets, tokens or real credentials. Fixture tokens are obviously fake values.
- Code, comments, commit messages and documents are in English.
