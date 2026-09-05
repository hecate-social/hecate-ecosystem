# Deployment Guide

> ⚠ **`hecate-daemon` is obsolete — confirmed 2026-09-05, dated
> 2026-09-01 in hecate-corpus's own
> `philosophy/INTEGRATION_TRANSPORTS.md`.** The repo is archived on
> GitHub and deleted from local disk, along with `hecate-web` and
> `hecate-gitops`. This is not "uncertain" or "pending" — there is no
> local/edge-device deployment path to document here, and this file no
> longer describes one.

Everything this guide previously covered — `~/.hecate/gitops/`, Quadlet
`.container` files, a reconciler watching for symlinks, `podman
auto-update` — was `hecate-daemon`'s own parked, never-actually-wired-up
local-browser-UI deployment plan. None of it was ever a working install
path (the "source of truth" directory it describes was hand-placed
files, not a git repository anything pulled from), and the daemon it
existed to deploy no longer exists to deploy.

## If you're looking for identity/auth instead

`hecate-daemon`'s role as a session host and plugin-app runtime was
superseded, not replaced 1:1 — see
[hecate-corpus's `philosophy/HECATE_AUTH_MODEL.md`](https://github.com/hecate-social/hecate-corpus/blob/main/philosophy/HECATE_AUTH_MODEL.md)
for the four channels (terminal via `macula-cli`, coding agent via
`macula-mcp`, an edge service's own operator website, a mobile app) that
took its place. None of them involve installing a daemon on your own
machine.

## If you're looking for how a hecate-* SERVICE deploys

A different thing from what this file used to describe: an actual
`hecate-*` service (e.g. `hecate-sentinel`, `hecate-rag`) running on the
fleet, not a per-user local daemon. See
[architecture.md](architecture.md)'s "Fleet (docker + watchtower,
GitOps-declared)" section — the real, live mechanism is
`macula-io/macula-demo/infrastructure`'s per-node `reconcile.manifest` +
docker-compose, applied by `hecate-reconcile.timer` (docker + watchtower
on the beam fleet). Podman + Quadlet + `podman auto-update` is real, but
only on the separate `msi00.lab` box, unrelated to anything this file
used to describe.
