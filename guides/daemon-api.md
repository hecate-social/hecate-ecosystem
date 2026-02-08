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
  "version": "0.7.2",
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

## Cartwheel Endpoints

Cartwheels represent projects or work items in the Agentic Lifecycle (ALC).

### GET /api/cartwheels

List all cartwheels.

**Response:**
```json
{
  "ok": true,
  "cartwheels": [
    {
      "id": "cw-abc123",
      "name": "Implement feature X",
      "status": "in_progress",
      "phase": "tni",
      "created_at": "2026-02-08T10:00:00Z"
    }
  ]
}
```

### GET /api/cartwheels/:id

Get a specific cartwheel.

**Response:**
```json
{
  "ok": true,
  "cartwheel": {
    "id": "cw-abc123",
    "name": "Implement feature X",
    "brief": "Add the new feature to the API",
    "status": "in_progress",
    "phase": "tni",
    "torch_id": "torch-xyz",
    "created_at": "2026-02-08T10:00:00Z"
  }
}
```

### POST /api/cartwheels

Create a new cartwheel.

**Request:**
```json
{
  "name": "Implement feature X",
  "brief": "Add the new feature to the API",
  "torch_id": "torch-xyz"
}
```

**Response:**
```json
{
  "ok": true,
  "id": "cw-abc123"
}
```

## Torch Endpoints

Torches represent broader initiatives or projects that contain cartwheels.

### GET /api/torches

List all torches.

**Response:**
```json
{
  "ok": true,
  "torches": [
    {
      "id": "torch-xyz",
      "name": "Q1 Platform Improvements",
      "status": "active",
      "cartwheel_count": 5
    }
  ]
}
```

### GET /api/torches/:id

Get a specific torch.

### POST /api/torches

Create a new torch.

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
