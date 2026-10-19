package protocol

import (
	"strings"
	"testing"
)

func TestDecodeFixtureRejectsInvalidBodyRepeat(t *testing.T) {
	tests := map[string]string{
		"body and body_repeat": `"body": "x", "body_repeat": {"text": "a", "count": 1}`,
		"zero count":           `"body_repeat": {"text": "a", "count": 0}`,
		"negative count":       `"body_repeat": {"text": "a", "count": -1}`,
		"empty text":           `"body_repeat": {"text": "", "count": 1}`,
	}
	for name, body := range tests {
		t.Run(name, func(t *testing.T) {
			data := `{"description": "d", "known_monitors": [],
				"request": {"method": "POST", "path": "/ping/t", "headers": {}, ` + body + `},
				"response": {"status": 200, "headers": {}, "body": "OK\n"}, "event": null}`
			if _, err := decodeFixture([]byte(data)); err == nil || !strings.Contains(err.Error(), "body_repeat") {
				t.Errorf("decodeFixture() error = %v, want an error about body_repeat", err)
			}
		})
	}
}
