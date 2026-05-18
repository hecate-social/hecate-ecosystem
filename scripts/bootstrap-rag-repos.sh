#!/usr/bin/env bash
#
# Bootstrap the four new RAG repos:
#   hecate-social/hecate-vector
#   hecate-social/hecate-embed
#   hecate-apps/hecate-app-rag
#   macula-io/macula-rag
#
# For each: create Codeberg repo, push local main, create GitHub repo
# (mirror target), configure Codeberg → GitHub push_mirror with
# sync_on_commit=true (1h fallback poll), disable Forgejo Actions on
# the Codeberg side.
#
# Idempotent on already-existing repos (skips creation, only configures).
#
# Required env (sourced from ~/.config/zshrc/01-secrets):
#   CODEBERG_GOD_TOKEN          — Codeberg admin token (create + configure)
#   CODEBERG_TO_GITHUB_TOKEN    — token Codeberg uses to push to GitHub
#   GITHUB_TOKEN                — GitHub admin token (create mirror repo)

set -euo pipefail

# ---- secrets ----------------------------------------------------------

if [[ -z "${CODEBERG_GOD_TOKEN:-}" || -z "${CODEBERG_TO_GITHUB_TOKEN:-}" || -z "${GITHUB_TOKEN:-}" ]]; then
    if [[ -f "$HOME/.config/zshrc/01-secrets" ]]; then
        # shellcheck disable=SC1091
        set -a; source "$HOME/.config/zshrc/01-secrets"; set +a
    fi
fi
: "${CODEBERG_GOD_TOKEN:?CODEBERG_GOD_TOKEN not set}"
: "${CODEBERG_TO_GITHUB_TOKEN:?CODEBERG_TO_GITHUB_TOKEN not set}"
: "${GITHUB_TOKEN:?GITHUB_TOKEN not set}"

WORKROOT="${WORKROOT:-$HOME/work/codeberg.org}"

# ---- repos table ------------------------------------------------------
# Format: <cb_org> <repo_name> <description>
REPOS=(
    "hecate-social|hecate-vector|In-BEAM HNSW vector index for Hecate (Rustler NIF over USearch)"
    "hecate-social|hecate-embed|Local multilingual sentence embeddings for Hecate (Rustler NIF)"
    "hecate-apps|hecate-app-rag|Local retrieval-augmented generation as a Hecate plugin"
    "macula-io|macula-rag|Federated semantic retrieval over the Macula mesh"
)

# ---- helpers ----------------------------------------------------------

cb_api() {
    local method="$1" path="$2" body="${3:-}"
    if [[ -n "$body" ]]; then
        curl -sS -X "$method" \
            -H "Authorization: token ${CODEBERG_GOD_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "$body" \
            "https://codeberg.org/api/v1${path}"
    else
        curl -sS -X "$method" \
            -H "Authorization: token ${CODEBERG_GOD_TOKEN}" \
            "https://codeberg.org/api/v1${path}"
    fi
}

gh_api() {
    local method="$1" path="$2" body="${3:-}"
    if [[ -n "$body" ]]; then
        curl -sS -X "$method" \
            -H "Authorization: token ${GITHUB_TOKEN}" \
            -H "Accept: application/vnd.github+json" \
            -H "Content-Type: application/json" \
            -d "$body" \
            "https://api.github.com${path}"
    else
        curl -sS -X "$method" \
            -H "Authorization: token ${GITHUB_TOKEN}" \
            -H "Accept: application/vnd.github+json" \
            "https://api.github.com${path}"
    fi
}

# ---- per-repo flow ----------------------------------------------------

bootstrap_one() {
    local org="$1" repo="$2" desc="$3"
    local local_path="${WORKROOT}/${org}/${repo}"
    local cb_url="https://codeberg.org/${org}/${repo}.git"
    local gh_url="https://github.com/${org}/${repo}.git"

    echo
    echo "── ${org}/${repo} ──"
    [[ -d "$local_path/.git" ]] || { echo "  ! no local git at $local_path; skipping"; return 1; }

    # 1. create Codeberg repo (idempotent)
    echo "  · Codeberg: create repo (if missing)"
    local cb_check
    cb_check=$(cb_api GET "/repos/${org}/${repo}")
    if echo "$cb_check" | grep -q '"full_name"'; then
        echo "    (exists)"
    else
        cb_api POST "/orgs/${org}/repos" "$(printf '{
            "name": "%s",
            "description": "%s",
            "private": false,
            "auto_init": false,
            "default_branch": "main",
            "license": "Apache-2.0"
        }' "$repo" "$desc")" > /dev/null
        echo "    (created)"
    fi

    # 2. push to Codeberg
    echo "  · Codeberg: push main"
    if git -C "$local_path" remote | grep -qx origin; then
        git -C "$local_path" remote set-url origin "$cb_url"
    else
        git -C "$local_path" remote add origin "$cb_url"
    fi
    git -C "$local_path" -c "credential.helper=!f() { echo username=oauth2; echo password=${CODEBERG_GOD_TOKEN}; }; f" \
        push -u origin main 2>&1 | sed 's/^/    /'

    # 3. disable Forgejo Actions on Codeberg (CI runs on GitHub mirror)
    echo "  · Codeberg: disable Forgejo Actions"
    cb_api PATCH "/repos/${org}/${repo}" '{"has_actions": false}' > /dev/null

    # 4. create GitHub mirror repo (idempotent)
    echo "  · GitHub: create mirror repo (if missing)"
    local gh_check
    gh_check=$(gh_api GET "/repos/${org}/${repo}")
    if echo "$gh_check" | grep -q '"full_name"'; then
        echo "    (exists)"
    else
        gh_api POST "/orgs/${org}/repos" "$(printf '{
            "name": "%s",
            "description": "%s (Codeberg mirror)",
            "private": false,
            "auto_init": false,
            "has_issues": false,
            "has_wiki": false,
            "has_projects": false
        }' "$repo" "$desc")" > /dev/null
        echo "    (created)"
    fi

    # 5. push directly to GitHub as well — push_mirror configuration
    #    via the Codeberg API requires direct-collaborator admin which
    #    the bot token doesn't have. Direct dual-push gets the mirror
    #    up immediately; the user can wire the Codeberg-side push_mirror
    #    via the web UI for future hands-off syncing.
    echo "  · GitHub: push main (direct, dual-push)"
    if git -C "$local_path" remote | grep -qx github; then
        git -C "$local_path" remote set-url github "git@github.com:${org}/${repo}.git"
    else
        git -C "$local_path" remote add github "git@github.com:${org}/${repo}.git"
    fi
    git -C "$local_path" push -u github main 2>&1 | sed 's/^/    /'

    # 6. (optional) configure Codeberg → GitHub push_mirror.
    #    Best-effort: will 403 unless the token's bearer is a direct
    #    admin collaborator. Continue regardless.
    echo "  · Codeberg: configure push_mirror → GitHub (best-effort)"
    local mirrors
    mirrors=$(cb_api GET "/repos/${org}/${repo}/push_mirrors" || true)
    if echo "$mirrors" | grep -q "github.com/${org}/${repo}"; then
        echo "    (push_mirror exists)"
    else
        local mirror_resp
        mirror_resp=$(cb_api POST "/repos/${org}/${repo}/push_mirrors" "$(printf '{
            "remote_address": "%s",
            "remote_username": "%s",
            "remote_password": "%s",
            "interval": "1h0m0s",
            "sync_on_commit": true
        }' "$gh_url" "$GITHUB_USER" "$CODEBERG_TO_GITHUB_TOKEN")" || true)
        if echo "$mirror_resp" | grep -q '"interval"'; then
            echo "    (configured)"
        elif echo "$mirror_resp" | grep -q '"message"'; then
            local msg
            msg=$(echo "$mirror_resp" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("message",""))' 2>/dev/null || echo "?")
            echo "    (skipped — $msg)"
        fi
    fi

    echo "  ✓ ${org}/${repo} bootstrapped"
}

# ---- run --------------------------------------------------------------

for entry in "${REPOS[@]}"; do
    IFS='|' read -r org repo desc <<< "$entry"
    bootstrap_one "$org" "$repo" "$desc"
done

echo
echo "Done."
