# protocol

The Simurg ping protocol: the specification, shared JSON contract fixtures and a Go reference package. Every Simurg client and server is tested against the same fixtures.

## Local setup

Prerequisites:

- [Docker](https://docs.docker.com/get-docker/) (OrbStack or Docker Desktop)

All language toolchains run in pinned Docker images, so nothing else needs to be installed on the host.

Validate the JSON Schemas and fixtures:

```sh
make validate-schemas
```

See [SPEC.md](SPEC.md) for the protocol and [fixtures/README.md](fixtures/README.md) for the fixture format.

## License

MIT. See [LICENSE](LICENSE).
