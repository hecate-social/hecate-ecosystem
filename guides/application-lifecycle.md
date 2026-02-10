# Application Lifecycle — Building Event-Sourced Applications for the Macula Mesh

Hecate structures software development as a **set of processes**, not a collection of database records. Each phase of building software is a first-class citizen with its own lifecycle, its own state, and its own dossier.

This guide explains the philosophy behind this approach and how it translates into building event-sourced, CQRS applications that run on the Macula mesh.

---

## The Insight

Traditional development tools model software creation as **data management**: create projects, update tasks, delete tickets. The verbs are CRUD. The nouns are passive containers.

Hecate models software creation as a **set of processes**: each phase is an active endeavor where a person sits at a desk, investigates, decides, produces, and hands off to the next desk.

**The test:** imagine a human sitting at a desk. What lands on their desk? What do they do with it? What do they pass to the next desk?

If the answer is "they manage a database record" — the model is wrong.
If the answer is "they investigate, decide, produce, and hand off" — the model is right.

---

## The Company Model

Hecate uses a company metaphor to make the Cartwheel architecture accessible. The metaphor maps directly to the technical model:

### Hierarchy

```
Venture (conglomerate)
  └── Division (co-operating departments)
       ├── CMD Department (Cartwheel) — front-office, handles Requests
       │    └── Desks (Spokes)
       ├── QRY Department (Cartwheel) — front-office, handles Inquiries
       │    └── Desks (Spokes)
       └── PRJ Department (Cartwheel) — back-office, Knowledge Warehouse
            └── Desks (Spokes)
```

### Mapping: Company Model to Cartwheel Architecture

| Company Model | Cartwheel Architecture | What It Is |
|---------------|----------------------|------------|
| **Venture** | Conglomerate | The overall business endeavor — multiple divisions co-operating |
| **Division** | 3 Departments | A cohesive piece of software (bounded context) with CMD, QRY, and PRJ |
| **Department** | **Cartwheel** | A single wheel — hub (aggregate) with spokes (desks) radiating outward |
| **Desk** | **Spoke** | A single capability — where work gets done (vertical slice) |
| **Dossier** | Aggregate | The folder of event slips passing through desks |

### Three Departments, Three Cartwheels

Each division contains exactly three departments. Each department is a Cartwheel:

| Department | Role | Cartwheel Type | Analogy |
|------------|------|----------------|---------|
| **CMD** | Commands — receives intents, produces events | Front-office | **Request desk** — customers walk in with requests |
| **QRY** | Queries — serves read models | Front-office | **Inquiry desk** — customers walk in asking questions |
| **PRJ** | Projections — subscribes to events, builds read models | Back-office | **Knowledge warehouse** — processes events into usable information |

The two front-office departments (CMD, QRY) face the outside world. The back-office department (PRJ) works internally, transforming raw events into optimized read models that QRY can serve.

---

## The Ten Processes

Hecate defines ten processes that cover the full software development lifecycle. Each process is its own aggregate with its own event stream.

| # | Process | Phase | Purpose |
|---|---------|-------|---------|
| 1 | `setup_venture` | Inception | Birth of the endeavor — name, brief, vision |
| 2 | `discover_divisions` | Discovery | Investigate the domain, identify bounded contexts |
| 3 | `design_division` | Architecture | Event storming, aggregate design, status flags |
| 4 | `plan_division` | Planning | Desk inventory, priorities, sprint sequencing |
| 5 | `generate_division` | Generation | Template-based code scaffolding |
| 6 | `test_division` | Testing | Verify quality, acceptance criteria |
| 7 | `deploy_division` | Deployment | CI/CD, staged rollouts |
| 8 | `monitor_division` | Monitoring | Observe production health, track SLAs |
| 9 | `rescue_division` | Rescue | Diagnose incidents, apply fixes, escalate |
| 10 | `guide_venture` | Orchestration | Track progress across all divisions |

### Mapping to ALC Phases

The four ALC phases that Hecate's AI personality adapts to correspond to groups of processes:

| ALC Phase | Processes | AI Behavior |
|-----------|----------|-------------|
| **DnA** (Discovery & Analysis) | `setup_venture`, `discover_divisions` | Asks questions, explores thoroughly, resists jumping to code |
| **AnP** (Architecture & Planning) | `design_division`, `plan_division` | Thinks in systems, proposes architectures, challenges assumptions |
| **TnI** (Testing & Implementation) | `generate_division`, `test_division` | Focused, precise, stays close to the code |
| **DnO** (Deployment & Operations) | `deploy_division`, `monitor_division`, `rescue_division` | Thinks about infrastructure, reliability, operational concerns |

`guide_venture` is cross-cutting — the orchestrator that observes all phases.

---

## Process Lifecycle Protocol

### Short-Lived vs Long-Lived

| Duration | Processes | Protocol |
|----------|-----------|----------|
| **Short** | `setup_venture` | Fire and done — one command, one event |
| **Long** | All division processes (discover through rescue) | start / pause / resume / complete |
| **Passive** | `guide_venture` | Observes only — consumes facts, produces nothing |

### State Machine

Every long-lived process implements:

```
            start
 pending ──────────► active
                       │ ▲
                 pause │ │ resume
                       ▼ │
                     paused
                       │
              complete │
                       ▼
                   completed
```

**Rules:**
- Domain-specific commands only work when state is `active`
- `pause` records a reason (blocked, waiting for input, break)
- `resume` clears the pause
- `complete` signals hand-off — facts flow to the next process

---

## The Dossier Model

### Process-Centric, Not Data-Centric

Most event-sourced systems treat aggregates as **data objects** with events applied to them. Hecate treats aggregates as **dossiers** — folders of event slips that accumulate history as they pass through desks.

```
Traditional:                         Hecate:
─────────────                        ───────
Aggregate = object with state        Dossier = ordered event slips
Events = mutations to the object     Slips = facts added at desks
Question: "What IS this thing?"      Question: "What has HAPPENED?"
```

### The Dossier Metaphor

Imagine a physical folder moving through an office:

1. **Dossier arrives** at a desk (spoke)
2. **Clerk reviews** the slips inside (events so far)
3. **Clerk may add** a new slip (new event) if business rules allow
4. **Dossier moves on** to the next desk

Each desk has a specific responsibility. The dossier accumulates slips as it moves through the process.

### Designing with Dossiers

When modeling a domain, ask four questions:

**1. What dossiers exist?** What are the things that accumulate history?

**2. What desks (spokes) process each dossier?** What actions can happen?

```
Design Dossier passes through:
├── start_design       (lifecycle: begin work)
├── design_aggregate   (add aggregate slip)
├── design_event       (add event slip)
├── complete_design    (lifecycle: hand off to planning)
└── archive_design     (walking skeleton: soft delete)
```

**3. What slips can be added?** Each desk adds specific event types.

| Desk (Spoke) | Slip (Event) |
|--------------|-------------|
| `design_aggregate` | `aggregate_designed_v1` |
| `design_event` | `event_designed_v1` |
| `complete_design` | `design_completed_v1` |

**4. What index cards do we need?** Projections (PRJ department) build read models so the QRY department can find dossiers without opening each one.

---

## CQRS Architecture — The Three Cartwheels

Every division produces apps following the three-department pattern. Each department is a Cartwheel with its own spokes (desks).

### CMD Cartwheel (Front-Office — Requests)

The CMD app handles incoming commands. Its name IS the process verb — no `manage_` prefix.

```
apps/design_division/                      ← CMD Department (1 Cartwheel)
├── src/
│   ├── design_division_app.erl
│   ├── design_division_sup.erl
│   ├── design_aggregate.erl               ← Hub (the dossier's state)
│   ├── start_design/                      ← Spoke (desk)
│   │   ├── start_design_v1.erl            (command)
│   │   ├── design_started_v1.erl          (event/slip)
│   │   └── maybe_start_design.erl         (handler)
│   ├── design_aggregate/                  ← Spoke (desk)
│   │   ├── design_aggregate_v1.erl
│   │   ├── aggregate_designed_v1.erl
│   │   ├── maybe_design_aggregate.erl
│   │   └── aggregate_designed_v1_to_pg.erl  (emitter)
│   ├── complete_design/                   ← Spoke (desk)
│   └── archive_design/                    ← Spoke (desk)
└── rebar.config
```

Each spoke is a **vertical slice** — command, event, handler, and emitters all live together. No `services/`, `handlers/`, or `utils/` directories.

### QRY Cartwheel (Front-Office — Inquiries)

The QRY app serves read models. Always named `query_{read_model}`. Its spokes are query endpoints.

```
apps/query_designs/                        ← QRY Department (1 Cartwheel)
├── src/
│   ├── query_designs_store.erl            ← Hub (SQLite connection)
│   ├── get_design_by_id/                  ← Spoke (desk)
│   │   └── get_design_by_id.erl
│   └── get_designs_page/                  ← Spoke (desk)
│       └── get_designs_page.erl
└── rebar.config
```

### PRJ Cartwheel (Back-Office — Knowledge Warehouse)

Projections live within the QRY app (they share the same read model store). Each projection is a spoke that subscribes to events and updates the knowledge warehouse.

```
apps/query_designs/                        ← also contains PRJ spokes
├── src/
│   ├── aggregate_designed_v1_to_designs/  ← PRJ Spoke (desk)
│   │   └── on_aggregate_designed_v1.erl   (event → SQLite row)
│   └── design_completed_v1_to_designs/    ← PRJ Spoke (desk)
│       └── on_design_completed_v1.erl     (event → SQLite row)
```

### How the Three Cartwheels Cooperate

```
                 CMD Cartwheel                    PRJ Cartwheel
                 (Front-Office)                   (Back-Office)

    Request ──► [desk: start_design]              [desk: on_aggregate_designed]
                    │                                  ▲
                    ▼                                  │
                Aggregate ──► Event ──► ReckonDB ──────┘
                (dossier)     (slip)    (store)         │
                                                       ▼
                                                  SQLite Read Model
                                                       │
                 QRY Cartwheel                         │
                 (Front-Office)                        │
                                                       │
    Inquiry ──► [desk: get_design_by_id] ◄─────────────┘
```

**CMD** receives requests and produces events. **PRJ** subscribes to events and updates the read model (knowledge warehouse). **QRY** serves inquiries from the read model.

---

## Event Flow Through the Stack

### Writing (CMD Cartwheel)

```
User Action
    │
    ▼
hecate-tui (Go)
    │  sends HTTP request
    ▼
hecate-daemon (Erlang/OTP)
    │
    ▼
hecate_api (Cowboy router)
    │  dispatches to desk API handler
    ▼
maybe_{verb}_{noun}.erl (Handler)
    │  validates, constructs event
    ▼
evoq (CQRS framework)
    │  dispatches command to aggregate
    ▼
reckon_evoq (Adapter)
    │  bridges evoq to event store
    ▼
reckon_gater (API)
    │
    ▼
reckon_db (Event Store)
    │  persists event with Raft consensus
    ▼
Stored ✓
```

### Projecting (PRJ Cartwheel)

```
reckon_db (Event Store)
    │  subscription delivers new event
    ▼
reckon_evoq (Adapter)
    │  translates to evoq event
    ▼
evoq (Projection behaviour)
    │  calls projection handler
    ▼
on_{event}_from_pg_project_to_sqlite_{table}.erl
    │  inserts/updates SQLite row
    ▼
query_{read_model}_store.erl (SQLite)
    │
    ▼
Updated ✓
```

### Querying (QRY Cartwheel)

```
User Action
    │
    ▼
hecate-tui (Go)
    │  sends HTTP GET
    ▼
hecate_api (Cowboy router)
    │  dispatches to query desk
    ▼
get_{item}_by_id.erl / get_{items}_page.erl
    │  reads from SQLite
    ▼
Response ✓
```

---

## Fact Flow Between Processes

Processes never call each other directly. They communicate through **facts** — events published to OTP process groups (internal) or the Macula mesh (external).

### Internal Facts (pg groups)

Within the same BEAM VM, processes emit facts to pg groups. Other processes subscribe and react.

```
design_division                    plan_division
    │                                  │
    │ emits: design_completed_v1       │ subscribes to: design_completed_v1
    │ → pg group                       │ ← pg group
    │                                  │
    └──────── fact ────────────────────►│
                                       │ reacts: now planning can start
```

### External Facts (Macula Mesh)

Across BEAM VMs (different machines, different agents), facts travel through the Macula mesh using DHT PubSub.

```
Agent A (beam00)                   Agent B (beam01)
    │                                  │
    │ emits: division_discovered_v1    │ subscribes to mesh topic
    │ → mesh topic                     │ ← mesh topic
    │                                  │
    └──────── mesh fact ──────────────►│
                                       │ reacts: starts own discovery
```

### The Lifecycle Is a Cycle

The fact flow is not linear — it's circular:

```
setup → discover → design → plan → generate → test → deploy → monitor
                      ▲                                           │
                      └──── rescue ◄──────────────────────────────┘
```

`rescue_division` can escalate back to `design_division` when an incident reveals a design flaw. This makes the lifecycle self-correcting.

---

## The Decision Cascade

Each process's output constrains the next process's input. This is by design — it compresses cognitive load:

```
setup: name = "my-saas-app"
  └─ constrains discovery scope

discover: divisions = [auth, billing, notify]
  └─ constrains design: 3 divisions to design

design(auth): aggregates = [user, session, credential]
  └─ constrains planning: desks must cover these aggregates

plan(auth): desks = [register_user, authenticate_user, ...]
  └─ constrains generation: exactly these desks, in this order

generate(auth): skeleton + desk files created
  └─ constrains testing: these files, these acceptance criteria

test(auth): all suites pass, coverage met
  └─ constrains deployment: quality gate passed

deploy(auth): v0.1.0 staged rollout
  └─ constrains monitoring: these endpoints, these SLAs
```

The AI-guided conversation at each phase only needs to cover that phase's decisions. Everything else is already settled by previous phases.

---

## The Guided Conversation Method

Hecate's AI assistant follows a structured protocol at each phase:

1. **Frame a decision** — Ask a clear, bounded question
2. **Present options** — Show tradeoffs as a table, not opinions
3. **User decides** — They own the choice
4. **Record the decision** — It becomes a constraint on all future decisions
5. **Build forward** — Each decision narrows the next decision's option space
6. **Produce an artifact** — The conversation output is structured data, not prose

### What Each Phase Produces

| Phase | Guided Conversation Produces |
|-------|------------------------------|
| `setup_venture` | Venture name + brief |
| `discover_divisions` | Division list with names, descriptions, boundary rationale |
| `design_division` | Aggregates, events, stream patterns, status flags |
| `plan_division` | Desk inventory, types, priorities, sprint sequence |
| `generate_division` | Minimal — mechanical, template-driven |
| `test_division` | Test strategy, acceptance criteria, coverage requirements |
| `deploy_division` | Release manifest, version, rollout strategy |
| `monitor_division` | Health check definitions, SLA thresholds |
| `rescue_division` | Diagnosis, root cause, fix plan, escalation decision |

---

## Vertical Slicing

### The Core Principle

> **Add a feature → Add a folder.**
> **Delete a feature → Delete a folder.**
> **No archaeology required.**

Every desk (spoke) contains everything needed for that capability:

| Component | Purpose |
|-----------|---------|
| Command (`*_v1.erl`) | The request structure |
| Event (`*_v1.erl`) | What happened (the slip) |
| Handler (`maybe_*.erl`) | Business logic and validation |
| Emitter (`*_to_pg.erl`) | Publishes facts internally |
| Emitter (`*_to_mesh.erl`) | Publishes facts externally |
| API handler (`*_api.erl`) | HTTP endpoint |

No shared `services/` folder. No central `handlers/` directory. Each desk is self-contained.

### Forbidden Directories

| Directory | Why It's Wrong |
|-----------|----------------|
| `services/` | Business logic belongs in the desk |
| `utils/` | Make it a library or put it in the desk |
| `helpers/` | Same as utils |
| `handlers/` | Handlers live with their commands |
| `listeners/` | Each domain owns its listeners |
| `managers/` | God modules wearing a mask |

---

## Naming Conventions

Names must scream intent. A new developer should understand the system's structure by reading directory names alone.

### CMD Apps

| Element | Pattern | Example |
|---------|---------|---------|
| App name | `{process_verb}_{subject}` | `design_division` |
| Desk (spoke) directory | `{verb}_{noun}/` | `design_aggregate/` |
| Command | `{verb}_{noun}_v{N}.erl` | `design_aggregate_v1.erl` |
| Event | `{noun}_{past_verb}_v{N}.erl` | `aggregate_designed_v1.erl` |
| Handler | `maybe_{verb}_{noun}.erl` | `maybe_design_aggregate.erl` |

### QRY Apps

| Element | Pattern | Example |
|---------|---------|---------|
| App name | `query_{read_model}` | `query_designs` |
| Projection (PRJ spoke) | `{event}_to_{table}/` | `aggregate_designed_v1_to_designs/` |
| Query (QRY spoke) | `get_{item}_by_id/` | `get_design_by_id/` |

### Events Are Business Verbs

Events capture what happened using domain language:

| Wrong (CRUD) | Right (Business Verb) |
|--------------|-----------------------|
| `design_created` | `aggregate_designed_v1` |
| `plan_updated` | `desks_sequenced_v1` |
| `test_deleted` | `testing_completed_v1` |

---

## Technology Stack

The application lifecycle is built on three independent ecosystems:

| Layer | Technology | Ecosystem |
|-------|-----------|-----------|
| **Mesh Networking** | HTTP/3 over QUIC, DHT, PubSub | [Macula](https://github.com/macula-io/macula-ecosystem) (macula-io) |
| **Event Sourcing** | ReckonDB, evoq, reckon_evoq | [Reckon](https://github.com/reckon-db-org/reckon-ecosystem) (reckon-db-org) |
| **Developer Studio** | hecate-daemon (Erlang), hecate-tui (Go) | [Hecate](https://github.com/hecate-social/hecate-ecosystem) (hecate-social) |

Macula provides the distributed communication layer. Reckon provides the event sourcing infrastructure. Hecate brings them together into a development workflow that treats each phase of software creation as a first-class process.

---

## Walking Skeleton Pattern

Every aggregate needs two desks (spokes) from day one:

1. **Initiate** — the birth event that starts the dossier
2. **Archive** — the soft delete (event sourcing has no deletes)

```
Status flags always include:
  INITIATED  = 1   (bit 0)
  ARCHIVED   = 2   (bit 1)
  ... domain-specific flags ...
```

Default list queries filter out archived items: `WHERE status & ARCHIVED = 0`

Without the archive desk, test data pollutes forever and there's no way to undo.

---

## Next Steps

- [Architecture](architecture.md) — Component details and deployment patterns
- [Mesh Integration](mesh-integration.md) — Connect to Macula, discover peers
- [Deployment](deployment.md) — GitOps deployment to Kubernetes
- [Personality System](personality-system.md) — Configure AI behavior per ALC phase
