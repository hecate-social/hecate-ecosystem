# Mesh Integration

Hecate connects to the Macula mesh network for peer-to-peer communication between agents.

## Overview

The Macula mesh provides:

- **Peer Discovery** - Find other Hecate instances via DHT
- **PubSub** - Subscribe to and publish events
- **RPC** - Call procedures on remote agents
- **Capabilities** - Advertise and discover agent capabilities

## Current Status

Mesh integration is under active development. Basic connectivity is implemented, with advanced features coming soon.

| Feature | Status |
|---------|--------|
| DHT Bootstrap | ✅ Implemented |
| Peer Discovery | ✅ Implemented |
| Basic PubSub | ✅ Implemented |
| RPC Calls | 🚧 In Progress |
| Capability Ads | 🚧 In Progress |
| NAT Traversal | 📋 Planned |

## Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                      Macula Mesh                                │
│                                                                 │
│    ┌─────────┐       ┌─────────┐       ┌─────────┐            │
│    │ Hecate  │◄─────►│   DHT   │◄─────►│ Hecate  │            │
│    │ Node A  │       │Bootstrap│       │ Node B  │            │
│    └────┬────┘       └─────────┘       └────┬────┘            │
│         │                                    │                 │
│         │         HTTP/3 over QUIC          │                 │
│         └────────────────────────────────────┘                 │
│                                                                 │
│    Topics:                                                      │
│    - hecate.capabilities.announced                             │
│    - hecate.agents.{realm}.online                              │
│    - hecate.learnings.shared                                   │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

## Configuration

### Daemon Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `HECATE_MESH_ENABLED` | Enable mesh connectivity | `false` |
| `HECATE_BOOTSTRAP_NODES` | Comma-separated bootstrap URLs | `boot.macula.io:4433` |
| `HECATE_REALM` | Realm identifier | `io.hecate.public` |
| `HECATE_AGENT_ID` | Unique agent identifier | Auto-generated |

### Enabling Mesh

Set the environment variable before starting the daemon:

```bash
export HECATE_MESH_ENABLED=true
export HECATE_REALM=io.mycompany.team

# Start daemon
docker run -d \
  -e HECATE_MESH_ENABLED=true \
  -e HECATE_REALM=io.mycompany.team \
  ghcr.io/hecate-social/hecate-daemon:latest
```

## Capabilities

Agents can advertise capabilities to the mesh, allowing other agents to discover what they can do.

### Capability Structure

```json
{
  "capability_mri": "mri:capability:io.hecate/code-review",
  "agent_id": "agent-abc123",
  "tags": ["code", "review", "erlang", "elixir"],
  "description": "Code review assistant specialized in BEAM languages",
  "demo_procedure": "review_code"
}
```

### Advertising a Capability

(API endpoint coming soon)

```bash
curl --unix-socket /run/hecate/daemon.sock \
  -X POST http://localhost/api/mesh/capabilities \
  -H "Content-Type: application/json" \
  -d '{
    "mri": "mri:capability:io.hecate/my-skill",
    "tags": ["skill", "demo"],
    "description": "My custom capability"
  }'
```

### Discovering Capabilities

(API endpoint coming soon)

```bash
curl --unix-socket /run/hecate/daemon.sock \
  "http://localhost/api/mesh/capabilities?tag=code-review"
```

## PubSub

Agents can subscribe to topics and publish events.

### Topic Naming Convention

```
hecate.{domain}.{event_type}

Examples:
- hecate.capabilities.announced
- hecate.agents.online
- hecate.learnings.shared
```

### Subscribing to a Topic

(API endpoint coming soon)

```bash
curl --unix-socket /run/hecate/daemon.sock \
  -X POST http://localhost/api/mesh/subscribe \
  -H "Content-Type: application/json" \
  -d '{"topic": "hecate.capabilities.announced"}'
```

### Publishing an Event

(API endpoint coming soon)

```bash
curl --unix-socket /run/hecate/daemon.sock \
  -X POST http://localhost/api/mesh/publish \
  -H "Content-Type: application/json" \
  -d '{
    "topic": "hecate.learnings.shared",
    "payload": {
      "learning_id": "learn-123",
      "category": "erlang",
      "title": "Pattern matching gotcha"
    }
  }'
```

## RPC

Remote Procedure Calls allow agents to invoke functions on other agents.

### Calling a Remote Procedure

(API endpoint coming soon)

```bash
curl --unix-socket /run/hecate/daemon.sock \
  -X POST http://localhost/api/mesh/rpc \
  -H "Content-Type: application/json" \
  -d '{
    "procedure": "mri:procedure:io.hecate/review_code",
    "args": {
      "code": "def foo(), do: :bar",
      "language": "elixir"
    }
  }'
```

### Registering a Procedure

(API endpoint coming soon)

Procedures are registered by the daemon based on configured capabilities.

## Security

### Realm Isolation

Agents in different realms cannot communicate directly. This provides multi-tenancy isolation.

### Identity

Each agent has a unique identity (DID) that is used for:
- Authentication to the mesh
- Signing published messages
- Verifying received messages

### Capability Authorization (Coming Soon)

UCAN tokens will provide fine-grained authorization:
- Who can call your procedures
- Who can read your published events
- What capabilities you can use

## Monitoring

### Check Mesh Status

```bash
curl --unix-socket /run/hecate/daemon.sock http://localhost/api/mesh/status
```

**Response:**

```json
{
  "ok": true,
  "connected": true,
  "realm": "io.hecate.public",
  "agent_id": "agent-abc123",
  "peers": 5,
  "subscriptions": ["hecate.capabilities.announced"]
}
```

### List Connected Peers

```bash
curl --unix-socket /run/hecate/daemon.sock http://localhost/api/mesh/peers
```

## Troubleshooting

### Cannot Connect to Mesh

1. Check mesh is enabled:
   ```bash
   echo $HECATE_MESH_ENABLED
   ```

2. Verify bootstrap nodes are reachable:
   ```bash
   curl -v https://boot.macula.io:4433/health
   ```

3. Check daemon logs for mesh errors.

### No Peers Found

- Ensure you're in the correct realm
- Check that bootstrap nodes are configured
- Other agents must be online in the same realm

### Messages Not Received

- Verify subscription is active
- Check topic name spelling
- Ensure publisher and subscriber are in the same realm

## Future Features

- **NAT Traversal** - Connect through firewalls without port forwarding
- **Encrypted Channels** - End-to-end encryption between agents
- **Capability Marketplace** - Discover and use capabilities across realms
- **Agent Federation** - Connect agents across organizational boundaries
