# Tooling image for the CI scripts in this directory: bash, git and bats.
FROM bats/bats:1.12.0

RUN apk add --no-cache git \
    && git config --system --add safe.directory '*'
