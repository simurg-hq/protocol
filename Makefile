.DEFAULT_GOAL := help

BASE ?= origin/main
HEAD_REF ?= HEAD
CI_TOOLS_IMAGE := $(notdir $(CURDIR))-ci-tools:local
SHELLCHECK_IMAGE := koalaman/shellcheck:v0.11.0
SCHEMA_IMAGE := $(notdir $(CURDIR))-schema:local
DOCKER_RUN := docker run --rm -v "$(CURDIR):/work" -w /work -e PR_SIZE_APPROVED

.PHONY: help ci-tools-image schema-image pr-size test-ci-scripts lint-ci-scripts validate-schemas

help: ## List available targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-18s %s\n", $$1, $$2}'

ci-tools-image:
	@docker build -q -t $(CI_TOOLS_IMAGE) scripts/ci >/dev/null

pr-size: ci-tools-image ## Measure this branch against BASE (default origin/main)
	$(DOCKER_RUN) --entrypoint bash $(CI_TOOLS_IMAGE) scripts/ci/pr-size.sh $(BASE) $(HEAD_REF)

test-ci-scripts: ci-tools-image ## Run the CI script tests
	$(DOCKER_RUN) $(CI_TOOLS_IMAGE) scripts/ci/tests

lint-ci-scripts: ## Lint the CI scripts with shellcheck
	$(DOCKER_RUN) $(SHELLCHECK_IMAGE) scripts/ci/*.sh

schema-image:
	@docker build -q -t $(SCHEMA_IMAGE) scripts/ci/schema >/dev/null

validate-schemas: schema-image ## Validate the JSON Schemas and fixtures
	$(DOCKER_RUN) --entrypoint sh $(SCHEMA_IMAGE) scripts/ci/validate-schemas.sh
