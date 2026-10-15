#!/bin/sh
#
# Validates the JSON Schemas and the protocol fixtures. Runs inside the image
# built from scripts/ci/schema/Dockerfile (check-jsonschema).
#
# 1. Every schema is valid against its metaschema.
# 2. Every fixture in fixtures/v1 is valid and named <nnn>-<behavior>.json.
# 3. The schemas accept every sample in schema/testdata/*/valid and reject
#    every sample in schema/testdata/*/invalid, so a schema that accepts
#    anything fails this gate.

set -eu

readonly EVENT_SCHEMA=schema/event.v1.schema.json
readonly FIXTURE_SCHEMA=schema/fixture.v1.schema.json
readonly TESTDATA=schema/testdata

failed=0

fail() {
    echo "FAIL: $*" >&2
    failed=1
}

check-jsonschema --check-metaschema "$EVENT_SCHEMA" "$FIXTURE_SCHEMA" || fail "metaschema"

check-jsonschema --schemafile "$FIXTURE_SCHEMA" fixtures/v1/*.json || fail "fixtures/v1"

for file in fixtures/v1/*.json; do
    case $(basename "$file") in
        [0-9][0-9][0-9]-*.json) ;;
        *) fail "$file is not named <nnn>-<behavior>.json" ;;
    esac
done

check-jsonschema --schemafile "$EVENT_SCHEMA" "$TESTDATA"/events/valid/*.json || fail "valid events"

expect_invalid() {
    schema=$1
    shift
    for file in "$@"; do
        if check-jsonschema --schemafile "$schema" "$file" >/dev/null 2>&1; then
            fail "$file was accepted by $schema"
        else
            echo "rejected as expected: $file"
        fi
    done
}

expect_invalid "$EVENT_SCHEMA" "$TESTDATA"/events/invalid/*.json
expect_invalid "$FIXTURE_SCHEMA" "$TESTDATA"/fixtures/invalid/*.json

if [ "$failed" -ne 0 ]; then
    exit 1
fi
echo "schemas and fixtures are valid"
