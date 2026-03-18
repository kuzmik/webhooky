# Webhooky — Design Spec

A Rails rewrite of [Webhook.site](https://webhook.site) that captures incoming HTTP requests to unique URLs and displays them in a real-time UI.

## Scope

**In scope:**
- Create unique webhook URLs (UUID-based)
- Capture any HTTP request sent to a webhook URL
- Display captured requests in real-time via WebSockets
- Configurable response (status code, content-type, body) per endpoint
- UI closely matching Webhook.site's layout and style

**Out of scope:**
- User accounts / authentication
- Email capture (emailhook)
- DNS capture (dnshook)
- Custom Actions / WebhookScript
- Paid tiers / billing

## Tech Stack

| Layer | Choice |
|---|---|
| Framework | Rails 8 |
| Database | SQLite |
| Real-time | ActionCable (WebSockets) |
| Frontend | Hotwire (Turbo + Stimulus) |
| CSS | Custom (no framework), matching Webhook.site aesthetic |
| Asset pipeline | Propshaft + importmap-rails |

## Data Model

### Token

Represents a unique webhook endpoint.

| Column | Type | Default | Notes |
|---|---|---|---|
| `uuid` | string(36) | generated | Primary key, UUID v4 |
| `default_status` | integer | 200 | HTTP status to return |
| `default_content_type` | string | `application/json` | Response content-type |
| `default_content` | text | `""` | Response body |
| `timeout` | integer | null | Delay before responding (seconds, max 30) |
| `cors` | boolean | true | Add CORS headers to response |
| `created_at` | datetime | | |
| `updated_at` | datetime | | |

### Request

A captured HTTP request.

| Column | Type | Notes |
|---|---|---|
| `uuid` | string(36) | Primary key, UUID v4 |
| `token_id` | string(36) | FK → Token.uuid |
| `method` | string | HTTP method (GET, POST, etc.) |
| `url` | text | Full request URL |
| `ip` | string | Client IP |
| `hostname` | string | Request hostname |
| `content` | text | Raw request body |
| `headers` | text | JSON-encoded headers hash |
| `query` | text | JSON-encoded query params |
| `form_data` | text | JSON-encoded form/multipart params |
| `content_size` | integer | Body size in bytes |
| `created_at` | datetime | |

Index on `token_id` + `created_at DESC` for efficient listing.

## Routing

```
GET  /                           → Landing page with "Create New URL" button
POST /tokens                     → Creates new token, redirects to /tokens/:uuid
GET  /tokens/:uuid               → Main UI (request list + detail)
GET  /tokens/:uuid/requests      → JSON: request list (50 per page, offset-based)
GET  /tokens/:uuid/requests/:id  → JSON: single request detail
DELETE /tokens/:uuid/requests/:id → Delete one request
DELETE /tokens/:uuid/requests     → Delete all requests for token (with JS confirm())
PUT  /tokens/:uuid               → Update token settings

ANY  /:uuid                      → Capture webhook (all HTTP methods)
ANY  /:uuid/:status              → Capture webhook with status override
```

A routing constraint validates the `:uuid` segment matches UUID v4 format (`/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i`), preventing conflicts with app routes. All UUID examples in the UI use full 36-character UUIDs (e.g., `550e8400-e29b-41d4-a716-446655440000`).

## Webhook Capture Flow

1. Request hits `ANY /:uuid`
2. Controller looks up Token by UUID (404 if not found)
3. Extracts method, URL, IP, headers, query params, body, form data
4. Creates Request record in SQLite
5. Broadcasts to ActionCable channel `token_<uuid>` with request data
6. Returns the token's configured response (status, content-type, body)
7. If `:status` path segment present, overrides status code
8. If token has `timeout` set, sleeps before responding (max 10s, to limit thread pool pressure)
9. If token has `cors` enabled, adds CORS headers

**Thread pool note:** The `timeout` feature blocks a Puma thread. With Puma's default 5-thread pool, this limits concurrent slow responses. Acceptable for local/dev use. For production, increase `RAILS_MAX_THREADS` or remove the timeout feature.

## Real-Time Updates (ActionCable)

### Channel: `TokenChannel`
- Client subscribes with `token_uuid`
- Server streams from `token_<uuid>`

### Broadcast payload
```json
{
  "request": {
    "uuid": "...",
    "method": "POST",
    "url": "/a1b2c3d4",
    "ip": "192.168.1.1",
    "content_size": 245,
    "created_at": "2026-03-18T10:30:00Z",
    "headers": { "Content-Type": "application/json", ... },
    "query": {},
    "content": "{\"event\": \"order.created\", ...}"
  },
  "total": 42
}
```

If serialized payload exceeds 100KB, `content` and `headers` are omitted and a `truncated: true` flag is set. The frontend fetches full details via API when the user clicks the request.

## UI Layout

### Page structure (matching Webhook.site)

```
+----------------------------------------------------------+
| [Logo: Webhooky]                        [+ New URL]      |
+----------------------------------------------------------+
| Your URL: http://localhost:3000/550e8400-...  [Copy]     |
| Status: [200] Content-Type: [application/json] Body: ... |
+---------------------------+------------------------------+
| Requests (42)  [Delete All]| POST /550e8400-...          |
|                           | 192.168.1.1 · 2 min ago      |
| ● POST 550e84  2m ago    |                              |
|   GET  550e84  5m ago    | Headers                      |
|   PUT  550e84  8m ago    |   Content-Type: application… |
|                           |   User-Agent: curl/8.0       |
|                           |                              |
|                           | Query String                 |
|                           |   (none)                     |
|                           |                              |
|                           | Body                         |
|                           |   {                          |
|                           |     "event": "order.created" |
|                           |     "data": { ... }          |
|                           |   }                          |
+---------------------------+------------------------------+
```

### Visual style
- Dark header bar (#1a1a2e or similar dark navy)
- White content area
- Color-coded method badges: green=GET, blue=POST, orange=PUT, red=DELETE, gray=other
- Monospace font for headers, body, query params
- Left panel: ~30% width, scrollable request list
- Right panel: ~70% width, selected request detail
- Empty state shows a curl example command

### Stimulus controllers
- `token_controller` — manages token settings form, copy-to-clipboard
- `requests_controller` — manages request list, selection state, ActionCable subscription
- `request_detail_controller` — displays selected request, fetches full data if truncated
- `flash_controller` — shows copy confirmation and other transient messages

## Retention & Cleanup

- Max 500 requests per token. On capture, if count exceeds 500, delete oldest.
- No automatic token expiry (tokens persist until server/DB is reset).
- Cleanup happens inline during webhook capture (delete oldest before insert).

## SQLite Configuration

- Enable WAL mode for better concurrent read/write performance
- Set `busy_timeout` to 5000ms to handle write contention gracefully
- Configured in `database.yml` or an initializer

## Frontend Architecture (Turbo + Stimulus)

- **Turbo Frames** are NOT used for real-time updates. The main UI is a single server-rendered page.
- **ActionCable + Stimulus** handles real-time: the `requests_controller` Stimulus controller subscribes to the token's ActionCable channel and manually prepends new request items to the DOM when broadcasts arrive.
- **Turbo** is used only for standard navigation (page transitions, form submissions).
- The request list is rendered server-side on initial load. Subsequent requests are added client-side via the Stimulus controller receiving ActionCable JSON and building DOM elements.
- Clicking a request in the left panel updates the right panel client-side (no server round-trip for selection). If the request was truncated in the broadcast, a fetch() call loads the full data.

## `form_data` Column

Populated only when the request Content-Type is `application/x-www-form-urlencoded` or `multipart/form-data`. Otherwise null. Displayed in the detail panel as a "Form Data" section only when present.

## CORS on API Routes

The JSON API routes (`/tokens/:uuid/requests`, etc.) are same-origin only — consumed by the Hotwire frontend on the same domain. No CORS headers needed on API routes.

## Error Handling

- Unknown UUID on webhook capture → 404 JSON response
- Invalid token settings update → 422 with validation errors
- Request body size limit: 1MB max (reject with 413)
- SQLite write errors → 500, logged

## Testing Strategy

- Model tests: Token and Request validations, associations
- Controller tests: webhook capture, JSON API endpoints, token settings
- System tests: full flow — create token, send webhook via curl, verify it appears in UI
- Channel tests: ActionCable subscription and broadcast
