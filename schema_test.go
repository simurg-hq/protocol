package protocol_test

import (
	"bytes"
	"path/filepath"
	"testing"

	"github.com/santhosh-tekuri/jsonschema/v6"
)

// compileSchema compiles a schema from the schema directory on disk.
// Compiling from the file lets the validator resolve the relative $ref from
// the fixture schema to the event schema.
func compileSchema(t *testing.T, name string) *jsonschema.Schema {
	t.Helper()
	schema, err := jsonschema.NewCompiler().Compile(filepath.Join("schema", name))
	if err != nil {
		t.Fatalf("compile %s: %v", name, err)
	}
	return schema
}

// validate checks a JSON document against a compiled schema.
func validate(t *testing.T, schema *jsonschema.Schema, data []byte) error {
	t.Helper()
	value, err := jsonschema.UnmarshalJSON(bytes.NewReader(data))
	if err != nil {
		t.Fatalf("parse JSON: %v", err)
	}
	return schema.Validate(value)
}
