.DEFAULT_GOAL := help

BASE ?= origin/main
HEAD_REF ?= HEAD
CI_TOOLS_IMAGE := $(notdir $(CURDIR))-ci-tools:local
SHELLCHECK_IMAGE := koalaman/shellcheck:v0.11.0
SCHEMA_IMAGE := $(notdir $(CURDIR))-schema:local
DOCKER_RUN := docker run --rm -v "$(CURDIR):/work" -w /work -e PR_SIZE_APPROVED -e TESTS_CHANGE_APPROVED

GO_IMAGE := golang:1.26.9-trixie@sha256:f06b7122f888680048afb247c4e5f49c0069eb6c4c1ccae0f3f4834527a8d22c
GOLANGCI_LINT_IMAGE := golangci/golangci-lint:v2.14.0@sha256:ad862ba6b3798cbe0fd9fd7408d498fd74fbd2623a92406b2fd3898faf0bf98f
GITLEAKS_IMAGE := zricethezav/gitleaks:v8.30.1@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f
GOVULNCHECK_VERSION := v1.9.0
# Named volumes keep the Go module and build caches between runs.
GO_RUN := $(DOCKER_RUN) -v $(notdir $(CURDIR))-go-mod:/go/pkg/mod -v $(notdir $(CURDIR))-go-build:/root/.cache/go-build

.PHONY: help ci-tools-image schema-image pr-size test-tampering test-ci-scripts lint-ci-scripts validate-schemas secrets-staged \
	check fmt-check lint test vulncheck secrets

help: ## List available targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-18s %s\n", $$1, $$2}'

ci-tools-image:
	@docker build -q -t $(CI_TOOLS_IMAGE) scripts/ci >/dev/null

pr-size: ci-tools-image ## Measure this branch against BASE (default origin/main)
	$(DOCKER_RUN) --entrypoint bash $(CI_TOOLS_IMAGE) scripts/ci/pr-size.sh $(BASE) $(HEAD_REF)

test-tampering: ci-tools-image ## Fail on assertions removed or changed and skips added in tests since BASE
	$(DOCKER_RUN) --entrypoint bash $(CI_TOOLS_IMAGE) scripts/ci/test-tampering.sh $(BASE) $(HEAD_REF)

test-ci-scripts: ci-tools-image ## Run the CI script tests
	$(DOCKER_RUN) $(CI_TOOLS_IMAGE) scripts/ci/tests

lint-ci-scripts: ## Lint the CI scripts with shellcheck
	$(DOCKER_RUN) $(SHELLCHECK_IMAGE) scripts/ci/*.sh

schema-image:
	@docker build -q -t $(SCHEMA_IMAGE) scripts/ci/schema >/dev/null

validate-schemas: schema-image ## Validate the JSON Schemas and fixtures
	$(DOCKER_RUN) --entrypoint sh $(SCHEMA_IMAGE) scripts/ci/validate-schemas.sh

check: fmt-check lint test vulncheck secrets ## Run all Go gates

fmt-check: ## Fail if a Go file is not gofmt-formatted
	$(GO_RUN) $(GO_IMAGE) sh -c 'files=$$(gofmt -l .); [ -z "$$files" ] || { echo "not gofmt-formatted:"; echo "$$files"; exit 1; }'

lint: ## Run golangci-lint (.golangci.yml)
	$(GO_RUN) $(GOLANGCI_LINT_IMAGE) golangci-lint run

test: ## Run the Go tests with the race detector
	$(GO_RUN) $(GO_IMAGE) go test -race ./...

vulncheck: ## Check the Go code and its dependencies for known vulnerabilities
	$(GO_RUN) $(GO_IMAGE) go run golang.org/x/vuln/cmd/govulncheck@$(GOVULNCHECK_VERSION) ./...

secrets: ## Scan the git history for secrets with gitleaks
	$(DOCKER_RUN) $(GITLEAKS_IMAGE) git --redact --no-banner -v .

# `git commit -a` and `git commit <path>` stage into a temporary index that Git
# names by its absolute host path; the container needs it relative to the repo.
secrets-staged: ## Scan the staged changes for secrets with gitleaks (pre-commit hook)
	$(DOCKER_RUN) -e GIT_INDEX_FILE=$(patsubst $(CURDIR)/%,%,$(or $(GIT_INDEX_FILE),.git/index)) \
		$(GITLEAKS_IMAGE) git --staged --redact --no-banner -v .
