package protocol

import (
	"bytes"
	"embed"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"path"
)

// Any matches any value in a fixture. Fixtures use it only for values the
// receiver generates: the event's ID, ReceivedAt and RunID, and response
// headers and bodies. See fixtures/README.md.
const Any = "$any"

//go:embed fixtures/v1/*.json
var fixturesV1 embed.FS

// Fixture is one request and the response and event it must produce.
// See fixtures/README.md and schema/fixture.v1.schema.json.
type Fixture struct {
	// Name is the file name, for example 001-start.json.
	Name        string `json:"-"`
	Description string `json:"description"`
	// KnownMonitors are the monitors the receiver knows before the request.
	KnownMonitors []Monitor `json:"known_monitors"`
	Request       Request   `json:"request"`
	Response      Response  `json:"response"`
	// Event is the expected event, or nil when the request must not emit one.
	Event *Event `json:"event"`
}

// Request is the HTTP request of a fixture.
type Request struct {
	Method string `json:"method"`
	// Path includes the query string and is sent as is.
	Path    string            `json:"path"`
	Headers map[string]string `json:"headers"`
	// Body is nil when the request has no body.
	Body *string `json:"body,omitempty"`
}

// Response is the HTTP response a fixture expects.
type Response struct {
	Status int `json:"status"`
	// Headers must be present in the response; names compare
	// case-insensitively and unlisted headers are not checked.
	Headers map[string]string `json:"headers"`
	Body    string            `json:"body"`
}

// FixturesV1 returns the fixtures of protocol version 1, sorted by name.
// They are embedded in the package, so callers need no files on disk.
func FixturesV1() ([]Fixture, error) {
	paths, err := fs.Glob(fixturesV1, "fixtures/v1/*.json")
	if err != nil {
		return nil, err
	}

	fixtures := make([]Fixture, 0, len(paths))
	for _, p := range paths {
		fixture, err := loadFixture(p)
		if err != nil {
			return nil, fmt.Errorf("fixture %s: %w", p, err)
		}
		fixtures = append(fixtures, fixture)
	}
	return fixtures, nil
}

// loadFixture decodes one fixture strictly: unknown fields and trailing data
// are errors, so a fixture the Go types cannot represent fails loudly.
func loadFixture(p string) (Fixture, error) {
	data, err := fixturesV1.ReadFile(p)
	if err != nil {
		return Fixture{}, err
	}

	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	var fixture Fixture
	if err := decoder.Decode(&fixture); err != nil {
		return Fixture{}, err
	}
	if _, err := decoder.Token(); !errors.Is(err, io.EOF) {
		return Fixture{}, errors.New("unexpected data after the fixture")
	}

	fixture.Name = path.Base(p)
	return fixture, nil
}
