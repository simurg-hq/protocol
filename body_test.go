package protocol_test

import (
	"testing"
	"unicode/utf8"

	"github.com/simurg-hq/protocol"
)

func TestRequestExpandedBody(t *testing.T) {
	text := "disk full\n"
	tests := []struct {
		name     string
		request  protocol.Request
		wantBody string
		wantOK   bool
	}{
		{"no body", protocol.Request{}, "", false},
		{"body", protocol.Request{Body: &text}, text, true},
		{"body_repeat", protocol.Request{BodyRepeat: &protocol.Repeat{Text: "ab", Count: 3}}, "ababab", true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			body, ok := tt.request.ExpandedBody()
			if body != tt.wantBody || ok != tt.wantOK {
				t.Errorf("ExpandedBody() = %q, %v; want %q, %v", body, ok, tt.wantBody, tt.wantOK)
			}
		})
	}
}

// The limits from SPEC.md, "Request body".
const (
	maxBodyBytes   = 102400
	maxOutputBytes = 10240
)

// The fixtures for the body limits must actually cross them, and an expected
// output tail must be what the tail rule keeps of the request body: its end,
// at most 10 KiB, starting on a UTF-8 character boundary.
func TestFixturesV1BodyLimits(t *testing.T) {
	fixtures, err := protocol.FixturesV1()
	if err != nil {
		t.Fatal(err)
	}

	for _, fixture := range fixtures {
		body, _ := fixture.Request.ExpandedBody()
		t.Run(fixture.Name, func(t *testing.T) {
			if fixture.Response.Status == 413 && len(body) <= maxBodyBytes {
				t.Errorf("413 for a body of %d bytes, which is within the limit", len(body))
			}
			if fixture.Event == nil || !fixture.Event.OutputTruncated {
				return
			}
			if fixture.Event.Output == nil {
				t.Fatal("output_truncated without output")
			}
			output := *fixture.Event.Output
			cut := len(body) - maxOutputBytes
			if cut <= 0 {
				t.Fatalf("output_truncated for a body of %d bytes, which fits", len(body))
			}
			for cut < len(body) && !utf8.RuneStart(body[cut]) {
				cut++
			}
			if want := body[cut:]; output != want {
				t.Errorf("output is %d bytes ending %q, want the %d-byte tail ending %q",
					len(output), tail(output), len(want), tail(want))
			}
		})
	}
}

// tail returns the last few bytes of s for error messages.
func tail(s string) string {
	if len(s) <= 12 {
		return s
	}
	return s[len(s)-12:]
}
