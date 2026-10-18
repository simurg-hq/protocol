# protocol

The Simurg ping protocol: the specification, shared JSON contract fixtures and a Go reference package. Every Simurg client and server is tested against the same fixtures.

## Local setup

Prerequisites:

- [Docker](https://docs.docker.com/get-docker/) (OrbStack or Docker Desktop)
- [Lefthook](https://lefthook.dev/) for Git hooks

All language toolchains and quality gates run in pinned Docker images, so nothing else needs to be installed on the host.

Run `lefthook install` once per clone to enable the Git hooks: format, static analysis and a secret scan on every commit. Tests run in CI on every pull request.

Validate the JSON Schemas and fixtures:

```sh
make validate-schemas
```

See [SPEC.md](SPEC.md) for the protocol and [fixtures/README.md](fixtures/README.md) for the fixture format.

## License

MIT. See [LICENSE](LICENSE).
