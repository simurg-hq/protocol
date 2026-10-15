package protocol_test

import (
	"encoding/json"
	"io/fs"
	"os"
	"testing"
	"time"

	"github.com/santhosh-tekuri/jsonschema/v6"
	"github.com/simurg-hq/protocol"
)

const (
	sampleID    = "01JA2B3C4D5E6F7G8H9JKMNPQS"
	sampleRunID = "01JA2B3C4D5E6F7G8H9JKMNPQR"
)

func TestEventSamplesRoundTrip(t *testing.T) {
	schema := compileSchema(t, "event.v1.schema.json")
	samples := os.DirFS("schema/testdata/events/valid")
	names, err := fs.Glob(samples, "*.json")
	if err != nil {
		t.Fatal(err)
	}
	if len(names) == 0 {
		t.Fatal("no event samples")
	}

	for _, name := range names {
		t.Run(name, func(t *testing.T) {
			data, err := fs.ReadFile(samples, name)
			if err != nil {
				t.Fatal(err)
			}
			var event protocol.Event
			if err := json.Unmarshal(data, &event); err != nil {
				t.Fatal(err)
			}
			assertValidEvent(t, schema, event)
		})
	}
}

// Every expected event in the fixtures, with "$any" replaced by generated
// values, is a valid event.
func TestFixtureEventsMatchEventSchema(t *testing.T) {
	fixtures, err := protocol.FixturesV1()
	if err != nil {
		t.Fatal(err)
	}

	schema := compileSchema(t, "event.v1.schema.json")
	for _, fixture := range fixtures {
		if fixture.Event == nil {
			continue
		}
		t.Run(fixture.Name, func(t *testing.T) {
			event := *fixture.Event
			if event.ID == protocol.Any {
				event.ID = sampleID
			}
			if event.ReceivedAt == protocol.Any {
				event.ReceivedAt = time.Now().UTC().Format(protocol.ReceivedAtLayout)
			}
			if event.RunID != nil && *event.RunID == protocol.Any {
				runID := sampleRunID
				event.RunID = &runID
			}
			assertValidEvent(t, schema, event)
		})
	}
}

// An event built in Go without metrics still encodes them as {} and [],
// because the schema requires both fields.
func TestEventWithoutMetricsMatchesSchema(t *testing.T) {
	exitCode := 0
	event := protocol.Event{
		V:          protocol.EventVersion,
		ID:         sampleID,
		Kind:       protocol.KindExit,
		ReceivedAt: time.Date(2026, 10, 15, 9, 0, 0, 0, time.UTC).Format(protocol.ReceivedAtLayout),
		Monitor:    protocol.Monitor{ProjectKey: "pk_abcdefghijklmnopqrstuvwxyz", Slug: "nightly-backup"},
		ExitCode:   &exitCode,
		Source:     protocol.SourceSDK,
	}

	assertValidEvent(t, compileSchema(t, "event.v1.schema.json"), event)
}

func assertValidEvent(t *testing.T, schema *jsonschema.Schema, event protocol.Event) {
	t.Helper()
	encoded, err := json.Marshal(event)
	if err != nil {
		t.Fatal(err)
	}
	if err := validate(t, schema, encoded); err != nil {
		t.Errorf("%s\n%v", encoded, err)
	}
}
