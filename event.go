package protocol

import "encoding/json"

// EventVersion is the value of Event.V for events of protocol version 1.
const EventVersion = 1

// ReceivedAtLayout is the time layout of Event.ReceivedAt: UTC with
// millisecond precision, for example 2026-10-15T09:00:00.123Z. Format the
// time in UTC: t.UTC().Format(ReceivedAtLayout).
const ReceivedAtLayout = "2006-01-02T15:04:05.000Z"

// Kind says which ping produced an event.
type Kind string

// Event kinds.
const (
	KindStart   Kind = "start"
	KindSuccess Kind = "success"
	KindFail    Kind = "fail"
	KindExit    Kind = "exit"
)

// Source says which kind of client sent a ping, derived from its User-Agent.
type Source string

// Event sources.
const (
	SourceCLI  Source = "cli"
	SourceSDK  Source = "sdk"
	SourceHTTP Source = "http"
)

// Event is what a receiver emits for every accepted ping. See SPEC.md,
// section Event, and schema/event.v1.schema.json.
//
// Every field is always present in JSON. Pointer fields encode nil as null.
type Event struct {
	V          int     `json:"v"`
	ID         string  `json:"id"`
	Kind       Kind    `json:"kind"`
	ReceivedAt string  `json:"received_at"`
	Monitor    Monitor `json:"monitor"`
	// RunID is set for start events and for pings that carry a rid.
	RunID *string `json:"run_id"`
	// ExitCode is set only for exit events.
	ExitCode        *int               `json:"exit_code"`
	Unverified      bool               `json:"unverified"`
	Source          Source             `json:"source"`
	IdempotencyKey  *string            `json:"idempotency_key"`
	Metrics         map[string]float64 `json:"metrics"`
	MetricsRejected []string           `json:"metrics_rejected"`
	Output          *string            `json:"output"`
	OutputTruncated bool               `json:"output_truncated"`
}

// MarshalJSON encodes nil Metrics as {} and nil MetricsRejected as [], as
// the schema requires.
func (e Event) MarshalJSON() ([]byte, error) {
	// plain has the fields of Event but not this method, so encoding it
	// does not call MarshalJSON again.
	type plain Event
	p := plain(e)
	if p.Metrics == nil {
		p.Metrics = map[string]float64{}
	}
	if p.MetricsRejected == nil {
		p.MetricsRejected = []string{}
	}
	return json.Marshal(p)
}

// Monitor identifies the monitor a ping is for: either by Token, or by
// ProjectKey and Slug. Create says whether the ping may create the monitor.
type Monitor struct {
	Token      string `json:"token"`
	ProjectKey string `json:"project_key"`
	Slug       string `json:"slug"`
	Create     bool   `json:"create"`
}

// MarshalJSON encodes only the fields of the form in use: {"token"} when
// Token is set, otherwise {"project_key", "slug", "create"}.
func (m Monitor) MarshalJSON() ([]byte, error) {
	if m.Token != "" {
		return json.Marshal(struct {
			Token string `json:"token"`
		}{m.Token})
	}
	return json.Marshal(struct {
		ProjectKey string `json:"project_key"`
		Slug       string `json:"slug"`
		Create     bool   `json:"create"`
	}{m.ProjectKey, m.Slug, m.Create})
}
