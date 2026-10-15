package protocol_test

import (
	"encoding/json"
	"io/fs"
	"os"
	"reflect"
	"testing"

	"github.com/simurg-hq/protocol"
)

// fixturesDir is the fixture directory on disk. Reading through an fs.FS
// keeps every read inside it.
var fixturesDir = os.DirFS("fixtures/v1")

// fixtureFiles returns the names of the fixture files on disk, sorted.
func fixtureFiles(t *testing.T) []string {
	t.Helper()
	names, err := fs.Glob(fixturesDir, "*.json")
	if err != nil {
		t.Fatal(err)
	}
	if len(names) == 0 {
		t.Fatal("no fixtures in fixtures/v1")
	}
	return names
}

func TestFixtureFilesMatchSchema(t *testing.T) {
	schema := compileSchema(t, "fixture.v1.schema.json")

	for _, name := range fixtureFiles(t) {
		t.Run(name, func(t *testing.T) {
			data, err := fs.ReadFile(fixturesDir, name)
			if err != nil {
				t.Fatal(err)
			}
			if err := validate(t, schema, data); err != nil {
				t.Error(err)
			}
		})
	}
}

func TestFixturesV1LoadsEveryFile(t *testing.T) {
	fixtures, err := protocol.FixturesV1()
	if err != nil {
		t.Fatal(err)
	}

	names := fixtureFiles(t)
	if len(fixtures) != len(names) {
		t.Fatalf("loaded %d fixtures, want %d", len(fixtures), len(names))
	}
	for i, fixture := range fixtures {
		if want := names[i]; fixture.Name != want {
			t.Errorf("fixture %d is named %q, want %q", i, fixture.Name, want)
		}
	}
}

// Loading a fixture and encoding it again must give the same JSON, so the Go
// types lose nothing: nulls stay null, an absent body stays absent, and a
// monitor keeps "create": false.
func TestFixturesV1RoundTrip(t *testing.T) {
	fixtures, err := protocol.FixturesV1()
	if err != nil {
		t.Fatal(err)
	}

	schema := compileSchema(t, "fixture.v1.schema.json")
	for _, fixture := range fixtures {
		t.Run(fixture.Name, func(t *testing.T) {
			original, err := fs.ReadFile(fixturesDir, fixture.Name)
			if err != nil {
				t.Fatal(err)
			}
			encoded, err := json.Marshal(fixture)
			if err != nil {
				t.Fatal(err)
			}

			if got, want := decode(t, encoded), decode(t, original); !reflect.DeepEqual(got, want) {
				t.Errorf("round trip changed the fixture\n got: %s\nwant: %s", encoded, original)
			}
			if err := validate(t, schema, encoded); err != nil {
				t.Error(err)
			}
		})
	}
}

// decode parses JSON into generic values for a comparison that ignores
// formatting and key order.
func decode(t *testing.T, data []byte) any {
	t.Helper()
	var value any
	if err := json.Unmarshal(data, &value); err != nil {
		t.Fatal(err)
	}
	return value
}
