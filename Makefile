.DEFAULT_GOAL := help

SCHEMA_IMAGE := $(notdir $(CURDIR))-schema:local
DOCKER_RUN := docker run --rm -v "$(CURDIR):/work" -w /work

GO_IMAGE := golang:1.26.9-trixie@sha256:f06b7122f888680048afb247c4e5f49c0069eb6c4c1ccae0f3f4834527a8d22c
# Named volumes keep the Go module and build caches between runs.
GO_RUN := $(DOCKER_RUN) -v $(notdir $(CURDIR))-go-mod:/go/pkg/mod -v $(notdir $(CURDIR))-go-build:/root/.cache/go-build

.PHONY: help schema-image validate-schemas test

help: ## List available targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-18s %s\n", $$1, $$2}'

schema-image:
	@docker build -q -t $(SCHEMA_IMAGE) scripts/ci/schema >/dev/null

validate-schemas: schema-image ## Validate the JSON Schemas and fixtures
	$(DOCKER_RUN) --entrypoint sh $(SCHEMA_IMAGE) scripts/ci/validate-schemas.sh

test: ## Run the Go tests with the race detector
	$(GO_RUN) $(GO_IMAGE) go test -race ./...
