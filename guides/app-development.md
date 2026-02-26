# Hecate App Development

How to build applications (plugins) for the Hecate platform using ReckonDB for event sourcing and the Martha plugin as a reference implementation.

## The Plugin Model

A Hecate plugin is an application that extends the platform. Every plugin has up to three parts:

| Part | Convention | Technology | Example |
|------|-----------|------------|---------|
| **Daemon** | `hecate-{name}d` | Erlang/OTP | `hecate-marthad` |
| **Frontend** | `hecate-{name}w` | SvelteKit (Tauri) | `hecate-marthaw` |
| **CLI** | `hecate {name}` | Subcommands via daemon | `hecate martha status` |

Each part runs as a separate container managed by systemd+podman. The reconciler in `~/.hecate/gitops/` handles lifecycle.

```
~/.hecate/
├── hecate-daemon/          # Core daemon data
│   ├── sqlite/
│   ├── reckon-db/
│   └── sockets/api.sock    # Core daemon Unix socket
├── hecate-marthad/         # Martha daemon data
│   ├── sqlite/
│   ├── reckon-db/
│   ├── sockets/api.sock    # Martha daemon Unix socket
│   └── hecate-agents/      # Cloned knowledge base
└── gitops/
    ├── system/             # Core daemon Quadlet files
    └── apps/               # Plugin Quadlet files
        ├── hecate-marthad.container
        └── hecate-marthaw.container
```

## Reference: hecate-martha

[hecate-martha](https://github.com/hecate-social/hecate-martha) is the reference plugin. It's an AI coding agent that uses venture lifecycle management. Study its structure before building your own.

```
hecate-martha/
├── daemon/                 # hecate-marthad (Erlang/OTP)
│   ├── apps/               # Domain apps (CQRS vertical slices)
│   │   ├── guide_ventures/          # CMD: venture lifecycle
│   │   ├── query_ventures/          # QRY: venture read models
│   │   └── ...
│   ├── src/                # Root app (supervisor, store, API)
│   ├── rebar.config
│   └── Dockerfile
├── web/                    # hecate-marthaw (SvelteKit)
│   ├── src/
│   ├── src-tauri/
│   └── package.json
└── .github/workflows/      # CI/CD → ghcr.io
```

## Event Sourcing with ReckonDB

Every Hecate plugin uses event sourcing. Commands produce events. Events are stored in ReckonDB. Projections build read models in SQLite.

### The Stack

| Package | Role | Hex |
|---------|------|-----|
| **reckon_db** | Event store (Khepri/Ra-based) | [hex.pm/reckon_db](https://hex.pm/packages/reckon_db) |
| **evoq** | CQRS/ES framework (aggregates, projections) | [hex.pm/evoq](https://hex.pm/packages/evoq) |
| **reckon_evoq** | Adapter: connects evoq to reckon_db | [hex.pm/reckon_evoq](https://hex.pm/packages/reckon_evoq) |

Add to your `rebar.config`:

```erlang
{deps, [
    {reckon_db, "1.3.2"},
    {evoq, "1.4.0"},
    {reckon_evoq, "1.2.0"},
    {esqlite, "0.8.8"},    %% For SQLite read models
    {cowboy, "2.12.0"}     %% For REST API
]}.
```

### Starting a Store

Each bounded context gets its own ReckonDB store. The root app creates all stores before domain apps start:

```erlang
%% In your_app.erl (application start)
start(_Type, _Args) ->
    DataDir = shared_paths:data_dir(),
    Stores = [
        {ventures_store, #{data_dir => filename:join(DataDir, "reckon-db/ventures")}},
        {tasks_store, #{data_dir => filename:join(DataDir, "reckon-db/tasks")}}
    ],
    lists:foreach(fun({Name, Config}) ->
        {ok, _} = reckon_db_sup:start_store(Name, Config)
    end, Stores),
    your_sup:start_link().
```

Domain apps reference their store by name — they never create stores themselves.

### Writing an Aggregate

An aggregate enforces business rules. It receives commands and produces events.

```erlang
-module(venture_aggregate).
-behaviour(evoq_aggregate).

-export([execute/2, apply/2]).

%% State FIRST in both callbacks (evoq convention)
execute(State, #{command_type := <<"initiate_venture_v1">>,
                 name := Name, description := Desc}) ->
    case maps:get(status, State, undefined) of
        undefined ->
            {ok, [#{
                event_type => <<"venture_initiated_v1">>,
                name => Name,
                description => Desc,
                initiated_at => erlang:system_time(second)
            }]};
        _ ->
            {error, already_initiated}
    end;

execute(State, #{command_type := <<"archive_venture_v1">>}) ->
    case evoq_bit_flags:has(maps:get(status, State, 0), ?ARCHIVED) of
        true -> {error, already_archived};
        false ->
            {ok, [#{event_type => <<"venture_archived_v1">>,
                     archived_at => erlang:system_time(second)}]}
    end.

apply(State, #{event_type := <<"venture_initiated_v1">>} = Event) ->
    State#{
        name => maps:get(name, Event),
        status => evoq_bit_flags:set(0, ?INITIATED)
    };
apply(State, #{event_type := <<"venture_archived_v1">>}) ->
    State#{status => evoq_bit_flags:set(maps:get(status, State), ?ARCHIVED)}.
```

Key rules:
- **`execute/2`** validates and returns events (or error). Must be pure.
- **`apply/2`** updates state from an event. Must be pure.
- **State comes first** in both callbacks — this is the evoq convention.
- **Use bit flags** for status fields (`evoq_bit_flags`).
- **No CRUD verbs** — use business verbs (`initiated`, `archived`, `confirmed`).

### Dispatching Commands

```erlang
%% In a handler module (e.g., maybe_initiate_venture.erl)
Cmd = #{
    command_type => <<"initiate_venture_v1">>,
    aggregate_module => venture_aggregate,
    aggregate_id => VentureId,
    name => <<"My Venture">>,
    description => <<"Building something great">>
},
Opts = #{
    store_id => ventures_store,
    adapter => reckon_evoq_adapter,
    consistency => eventual
},
case evoq_dispatcher:dispatch(Cmd, Opts) of
    {ok, Events} -> {ok, Events};
    {error, Reason} -> {error, Reason}
end.
```

### Building Projections

Projections subscribe to events and update SQLite read models:

```erlang
-module(venture_initiated_v1_to_ventures).

-export([start_link/0, init/1, handle_events/2]).

start_link() ->
    %% Subscribe to ventures_store for venture_initiated_v1 events
    evoq_subscriptions:subscribe(
        ventures_store,
        <<"venture_initiated_v1">>,
        ?MODULE,
        #{from => 0},  %% Catch-up from beginning
        []
    ).

handle_events(Events, State) ->
    lists:foreach(fun(Event) ->
        Data = maps:get(data, Event),
        Db = get_db(),
        esqlite3:exec(Db,
            "INSERT OR REPLACE INTO ventures (id, name, status, initiated_at) "
            "VALUES (?1, ?2, ?3, ?4)",
            [maps:get(aggregate_id, Event),
             maps:get(name, Data),
             maps:get(status, Data, 1),
             maps:get(initiated_at, Data)])
    end, Events),
    {ok, State}.
```

### Querying Read Models

Query modules read directly from SQLite. No event store involved.

```erlang
-module(get_ventures_page_api).

-export([routes/0, init/2]).

routes() ->
    [{"/api/ventures", ?MODULE, []}].

init(Req0, State) ->
    Db = get_db(),
    {ok, Rows} = esqlite3:fetchall(Db,
        "SELECT id, name, status, initiated_at FROM ventures ORDER BY initiated_at DESC"),
    Ventures = [#{id => Id, name => Name, status => S, initiated_at => T}
                || {Id, Name, S, T} <- Rows],
    Body = json:encode(#{ok => true, ventures => Ventures}),
    Req = cowboy_req:reply(200,
        #{<<"content-type">> => <<"application/json">>}, Body, Req0),
    {ok, Req, State}.
```

## Vertical Slicing: The Desk Pattern

Every capability is a **desk** — a directory containing all related code:

```
apps/guide_ventures/src/
├── guide_ventures_sup.erl              # Domain supervisor
├── guide_ventures_app.erl              # Domain application
├── venture_aggregate.erl               # Shared aggregate state
│
├── initiate_venture/                   # Desk: initiate a venture
│   ├── initiate_venture_v1.erl         # Command definition
│   ├── venture_initiated_v1.erl        # Event definition
│   └── maybe_initiate_venture.erl      # Handler (business logic)
│
├── archive_venture/                    # Desk: archive a venture
│   ├── archive_venture_v1.erl
│   ├── venture_archived_v1.erl
│   └── maybe_archive_venture.erl
│
└── venture_initiated_v1_to_mesh/       # Desk: publish to mesh
    ├── venture_initiated_v1_to_mesh_sup.erl
    └── venture_initiated_v1_to_mesh.erl
```

Rules:
- **One desk per capability.** Command + event + handler live together.
- **No horizontal folders.** No `handlers/`, `services/`, `utils/`, `projections/`.
- **Names scream intent.** `initiate_venture/` tells you exactly what it does.
- **Desks with workers get supervisors.** Emitters, listeners, and process managers have their own supervisor within the desk directory.

## Cross-Domain Integration: Process Managers

When Domain A needs to trigger actions in Domain B, use a **process manager** — never dispatch commands directly between domains.

```
Domain A (guide_ventures)
    ↓ emits venture_initiated_v1
    ↓ stored in ventures_store

Process Manager (on_venture_initiated_create_default_divisions)
    ↓ subscribes to ventures_store events
    ↓ dispatches create_division_v1 to Domain B

Domain B (guide_divisions)
    ↓ receives command
    ↓ stores division_initiated_v1
```

Process managers live in the **target domain** (they need to know the target command structure):

```
apps/guide_divisions/src/
└── on_venture_initiated_create_default_divisions/
    ├── on_venture_initiated_create_default_divisions_sup.erl
    └── on_venture_initiated_create_default_divisions.erl
```

## Naming Conventions

| Element | Format | Example |
|---------|--------|---------|
| CMD app | `{process_verb}_{subject}` | `guide_ventures` |
| QRY app | `query_{subject_plural}` | `query_ventures` |
| Command | `{verb}_{subject}_v{N}` | `initiate_venture_v1` |
| Event | `{subject}_{past_verb}_v{N}` | `venture_initiated_v1` |
| Handler | `maybe_{verb}_{subject}` | `maybe_initiate_venture` |
| Projection | `{event}_to_{table}` | `venture_initiated_v1_to_ventures` |
| Process Mgr | `on_{event}_{action}` | `on_venture_initiated_create_divisions` |
| Desk dir | `{verb}_{subject}/` | `initiate_venture/` |

## Deployment

Plugin containers are deployed via Quadlet `.container` files in `~/.hecate/gitops/apps/`:

```ini
# ~/.hecate/gitops/apps/hecate-marthad.container
[Unit]
Description=Hecate Martha Daemon

[Container]
Image=ghcr.io/hecate-social/hecate-marthad:latest
AutoUpdate=registry
Network=host

Volume=%h/.hecate/hecate-marthad:/home/hecate/.hecate/hecate-marthad:Z
Volume=%h/.hecate/secrets:/home/hecate/.hecate/secrets:ro,Z

Environment=HOME=%h
Environment=HECATE_HOSTNAME=%H
Environment=HECATE_USER=%u

[Service]
Restart=always

[Install]
WantedBy=default.target
```

The reconciler watches `~/.hecate/gitops/` and symlinks Quadlet files to systemd. Drop a `.container` file, and the service starts automatically.

CI/CD pushes `:latest` + semver tags to ghcr.io. `AutoUpdate=registry` means `podman auto-update` pulls new images automatically.

## Testing

Aggregates are pure functions — test them without a database:

```erlang
-module(venture_aggregate_tests).
-include_lib("eunit/include/eunit.hrl").

initiate_test() ->
    Cmd = #{command_type => <<"initiate_venture_v1">>,
            name => <<"Test">>, description => <<"Desc">>},
    {ok, [Event]} = venture_aggregate:execute(#{}, Cmd),
    ?assertEqual(<<"venture_initiated_v1">>, maps:get(event_type, Event)),

    State = venture_aggregate:apply(#{}, Event),
    ?assertEqual(<<"Test">>, maps:get(name, State)).

already_initiated_test() ->
    State = #{status => 1},  %% INITIATED flag set
    Cmd = #{command_type => <<"initiate_venture_v1">>,
            name => <<"X">>, description => <<"Y">>},
    ?assertEqual({error, already_initiated},
                 venture_aggregate:execute(State, Cmd)).
```

Run tests:

```bash
rebar3 eunit
```

## Further Reading

- [Reckon Ecosystem](https://github.com/reckon-db-org/reckon-ecosystem) — deep dives into ReckonDB, evoq, projections
- [Mental Model](mental-model.md) — the Venture/Division/Department/Desk hierarchy
- [Application Lifecycle](application-lifecycle.md) — the ten processes from setup to rescue
- [Macula Mesh](macula-mesh.md) — how plugins connect to the mesh
