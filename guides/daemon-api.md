# Daemon API Reference

The Hecate daemon exposes a REST API over a Unix socket at `/run/hecate/daemon.sock`.

## Making Requests

Use `curl` with the `--unix-socket` option:

```bash
curl --unix-socket /run/hecate/daemon.sock http://localhost/api/health
```

All responses are JSON with the format:

```json
// Success
{"ok": true, "field": "value", ...}

// Error
{"ok": false, "error": "description"}
```

## Health & Status

### GET /api/health

Check daemon health and status.

**Response:**
```json
{
  "ok": true,
  "status": "healthy",
  "version": "0.8.0",
  "uptime_seconds": 3600
}
```

## LLM Endpoints

### GET /api/llm/models

List all available models across all providers.

**Response:**
```json
{
  "ok": true,
  "models": [
    {
      "name": "llama3.2:latest",
      "provider": "ollama",
      "size": "3.8B"
    },
    {
      "name": "claude-3-5-sonnet-20241022",
      "provider": "anthropic"
    }
  ]
}
```

### GET /api/llm/health

Check health of all LLM providers.

**Response:**
```json
{
  "ok": true,
  "providers": {
    "ollama": {"status": "healthy", "models": 5},
    "anthropic": {"status": "healthy"},
    "openai": {"status": "not_configured"},
    "google": {"status": "not_configured"}
  }
}
```

### POST /api/llm/chat

Send a chat message to an LLM.

**Request:**
```json
{
  "model": "llama3.2:latest",
  "messages": [
    {"role": "system", "content": "You are a helpful assistant."},
    {"role": "user", "content": "Hello!"}
  ],
  "stream": false
}
```

**Response (non-streaming):**
```json
{
  "ok": true,
  "content": "Hello! How can I help you today?",
  "model": "llama3.2:latest",
  "usage": {
    "prompt_tokens": 15,
    "completion_tokens": 8
  }
}
```

**Response (streaming):**

When `stream: true`, the response uses Server-Sent Events (SSE):

```
data: {"content": "Hello", "done": false}

data: {"content": "!", "done": false}

data: {"content": " How", "done": false}

data: {"content": "", "done": true}
```

### POST /api/llm/providers/reload

Reload provider configuration from environment variables.

**Response:**
```json
{
  "ok": true,
  "providers_loaded": ["ollama", "anthropic"]
}
```

## Venture Endpoints

Ventures represent business endeavors that contain divisions.

### GET /api/ventures

List all ventures.

**Response:**
```json
{
  "ok": true,
  "ventures": [
    {
      "id": "v-abc123",
      "name": "my-saas-app",
      "brief": "A multi-tenant SaaS platform",
      "status": 1,
      "setup_at": "2026-02-10T10:00:00Z"
    }
  ]
}
```

### GET /api/ventures/:id

Get a specific venture.

### POST /api/ventures

Set up a new venture.

**Request:**
```json
{
  "name": "my-saas-app",
  "brief": "A multi-tenant SaaS platform"
}
```

**Response:**
```json
{
  "ok": true,
  "id": "v-abc123"
}
```

### GET /api/ventures/:id/status

Get the full venture status from `guide_venture`, including the current process and health of each division.

**Response:**
```json
{
  "ok": true,
  "venture_id": "v-abc123",
  "name": "my-saas-app",
  "divisions": {
    "auth": {"process": "generate_division", "state": "active", "health": "ok"},
    "billing": {"process": "design_division", "state": "paused", "health": "unknown"}
  }
}
```

## Discovery Endpoints

### POST /api/ventures/:venture_id/discovery/start

Start the discovery process for a venture.

### POST /api/ventures/:venture_id/discovery/discover

Discover a new division within the venture.

**Request:**
```json
{
  "division_name": "auth",
  "description": "Authentication and authorization bounded context",
  "rationale": "Separate identity concerns from billing and notifications"
}
```

### POST /api/ventures/:venture_id/discovery/complete

Complete the discovery phase.

### GET /api/ventures/:venture_id/divisions

List discovered divisions for a venture.

## Division Process Endpoints

Each division process (design, plan, generate, test, deploy, monitor, rescue) follows the same pattern:

### Lifecycle Commands

```
POST /api/divisions/:division_id/{process}/start
POST /api/divisions/:division_id/{process}/pause
POST /api/divisions/:division_id/{process}/resume
POST /api/divisions/:division_id/{process}/complete
```

Where `{process}` is one of: `design`, `plan`, `generate`, `test`, `deploy`, `monitor`, `rescue`.

### Domain Commands (examples)

```
POST /api/divisions/:division_id/design/aggregate    — design an aggregate
POST /api/divisions/:division_id/design/event         — design an event
POST /api/divisions/:division_id/plan/desk            — inventory a desk
POST /api/divisions/:division_id/plan/sequence        — sequence desks
POST /api/divisions/:division_id/generate/skeleton    — generate skeleton
POST /api/divisions/:division_id/generate/desk        — generate a desk
POST /api/divisions/:division_id/test/suite           — run test suite
POST /api/divisions/:division_id/deploy/release       — deploy a release
POST /api/divisions/:division_id/monitor/incident     — raise an incident
POST /api/divisions/:division_id/rescue/diagnose      — diagnose incident
POST /api/divisions/:division_id/rescue/fix           — apply a fix
```

### Read Endpoints (examples)

```
GET /api/divisions/:division_id/designs               — list designs
GET /api/divisions/:division_id/plans                  — list plans
GET /api/divisions/:division_id/generations            — list generations
GET /api/divisions/:division_id/tests                  — list test results
GET /api/divisions/:division_id/deployments            — list deployments
GET /api/divisions/:division_id/monitoring             — list health checks
GET /api/divisions/:division_id/rescues                — list rescues
```

## Geo Endpoints

Geographic restriction status (if enabled).

### GET /api/geo/status

Check geographic access status.

**Response:**
```json
{
  "ok": true,
  "allowed": true,
  "country": "NL",
  "checked_at": "2026-02-08T10:00:00Z"
}
```

## Mesh Endpoints

(Coming soon)

### GET /api/mesh/status

Check mesh connection status.

### GET /api/mesh/peers

List connected peers.

### POST /api/mesh/capabilities

Advertise a capability to the mesh.

## Error Codes

| Code | Description |
|------|-------------|
| `model_not_found` | Requested model is not available |
| `provider_error` | LLM provider returned an error |
| `validation_error` | Request validation failed |
| `not_found` | Resource not found |
| `geo_restricted` | Access denied due to geographic restriction |

## Rate Limits

The daemon does not impose rate limits. Rate limiting, if needed, should be implemented at the infrastructure level.

## Authentication

The Unix socket provides implicit authentication - only processes on the same machine can access the API. No additional authentication is required.

For networked deployments, use a reverse proxy with appropriate authentication.
