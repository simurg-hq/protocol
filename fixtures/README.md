# Fixtures

Contract fixtures for the ping protocol. Each file is one request and the
response and event it must produce. Every receiver and client implementation
runs these fixtures; `SPEC.md` is the source of truth and the fixtures pin it
down.

Fixtures for protocol version 1 live in `v1/` and are named
`<nnn>-<behavior>.json`. They are validated against
[`schema/fixture.v1.schema.json`](../schema/fixture.v1.schema.json) in CI
(`make validate-schemas`). Within version 1, existing fixtures never change
meaning; new behavior gets new fixtures.

## Format

| Field | Meaning |
| --- | --- |
| `description` | What the fixture shows, in one or two sentences. |
| `known_monitors` | Monitors the receiver knows before the request, in the event's `monitor` shape. A ping for any other monitor is accepted with `unverified: true`. |
| `request.method` | HTTP method. |
| `request.path` | Path including the query string, sent as is. |
| `request.headers` | Request headers. No other headers are sent; a missing `User-Agent` means no such header. |
| `request.body` | Request body as a string. Absent, together with `request.body_repeat`, means no body. |
| `request.body_repeat` | A large body written compactly: `{"text": "a", "count": 102401}` is the body `text` repeated `count` times (here 102,401 bytes). Not allowed together with `request.body`. |
| `response.status` | Expected status code. |
| `response.headers` | Headers the response must contain. Names are compared case-insensitively; headers not listed are not checked. |
| `response.body` | Expected body. Empty string for `HEAD` responses. |
| `event` | Expected event, or `null` when the request must not emit an event. |

## Matching rules

- Values are compared exactly, after parsing JSON. Numbers compare by value.
- `"$any"` matches any value. It is allowed only for values the receiver
  generates: the event's `id`, `received_at` and `run_id`, and response
  headers and bodies.
- For a `start` fixture, the `Run-Id` response header, the response body
  without its trailing `\n` (not for `HEAD`) and the event's `run_id` must
  all be the same run ID.
- An event matches only if it is also valid against
  [`schema/event.v1.schema.json`](../schema/event.v1.schema.json).
