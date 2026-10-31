#!/usr/bin/env bash
# sync.sh — install or update the DV swarm kit in a repo checkout.
#
#   ./sync.sh [--check] <path-to-repo-checkout>
#
# Copies every file under kit/ into the repo (kit-owned files are overwritten; anything else, e.g. a repo-only
# extra agent, is left alone), then:
#   - .claude/swarm.env      created from templates/swarm.env.example if missing (never overwritten - fill it in)
#   - CLAUDE.md              the <!-- swarm-kit:begin/end --> block replaced (appended if absent)
#   - Makefile               `include swarm.mk` appended if absent; fails if the Makefile defines a kit target
#   - .gitignore             $RR_DIR/runs/ and docker/last-run-metrics.json ignored
#   - .claude/swarm-kit.version  the kit version installed
#   - Dockerfile             checked (not edited): needs stages `tools` and `full` (last), ARG WITH_CLAUDE
# It does not commit, push or touch RTL. --check: report drift only, change nothing (exit 1 on drift).
set -euo pipefail
KIT="$(cd "$(dirname "$0")" && pwd)"
check=0
[ "${1:-}" = "--check" ] && { check=1; shift; }
repo="${1:?usage: sync.sh [--check] <repo checkout>}"
repo="$(cd "$repo" && pwd)"
ver="$(git -C "$KIT" describe --tags --match 'v*.*.*' --always --dirty 2>/dev/null || echo dev)"
KIT_TARGETS="heavy board board-wait swarm swarm-rr swarm-dry swarm-profile swarm-kit-check batch"
drift=0; warn(){ echo "sync: $*" >&2; }

# 1. kit-owned files
while IFS= read -r -d '' f; do
  rel="${f#"$KIT/kit/"}"
  if [ "$check" = 1 ]; then
    cmp -s "$f" "$repo/$rel" || { warn "drift: $rel"; drift=1; }
  else
    mkdir -p "$(dirname "$repo/$rel")"; cp "$f" "$repo/$rel"
    case "$rel" in *.sh) chmod +x "$repo/$rel" ;; esac
  fi
done < <(find "$KIT/kit" -type f -print0)

if [ "$check" = 1 ]; then
  echo "kit: $(cat "$repo/.claude/swarm-kit.version" 2>/dev/null || echo none) installed, $ver available"
  [ "$drift" = 0 ] && echo "sync --check: no drift"; exit "$drift"
fi

# 2. profile
if [ ! -f "$repo/.claude/swarm.env" ]; then
  cp "$KIT/templates/swarm.env.example" "$repo/.claude/swarm.env"
  warn "created .claude/swarm.env from the template - FILL IT IN before running a swarm"
fi
rr_dir="$(cd "$repo" && bash -c '. docker/profile.sh >/dev/null; echo "${RR_DIR:-dv/random}"')"

# 3. CLAUDE.md block
python3 - "$repo/CLAUDE.md" "$KIT/templates/CLAUDE-swarm.md" <<'PY'
import os, re, sys
path, tpl = sys.argv[1], open(sys.argv[2]).read().rstrip() + "\n"
s = open(path).read() if os.path.exists(path) else "# CLAUDE.md\n"
pat = re.compile(r"<!-- swarm-kit:begin.*?<!-- swarm-kit:end -->\n?", re.S)
s = pat.sub(lambda m: tpl, s) if pat.search(s) else s.rstrip() + "\n\n" + tpl
open(path, "w").write(s)
PY

# 4. Makefile include
mk="$repo/Makefile"
if [ -f "$mk" ]; then
  clash=""
  for t in $KIT_TARGETS; do grep -qE "^$t:" "$mk" && clash="$clash $t"; done
  [ -n "$clash" ] && { warn "Makefile defines kit target(s):$clash - remove them (swarm.mk provides them), then re-run"; exit 1; }
  grep -qE '^-?include +swarm\.mk' "$mk" || printf '\n# shared swarm/infra targets (markrthomas/dv-swarm-kit)\ninclude swarm.mk\n' >> "$mk"
else
  warn "no root Makefile - swarm.mk needs one (create it with 'include swarm.mk' and the DV targets)"
fi

# 5. .gitignore
gi="$repo/.gitignore"; touch "$gi"
for p in "/$rr_dir/runs/" "/docker/last-run-metrics.json"; do grep -qxF "$p" "$gi" || echo "$p" >> "$gi"; done
mkdir -p "$repo/$rr_dir/board"; [ -e "$repo/$rr_dir/board/.gitkeep" ] || : > "$repo/$rr_dir/board/.gitkeep"

# 6. version stamp
echo "$ver" > "$repo/.claude/swarm-kit.version"

# 7. Dockerfile contract (checked, not edited)
df="$repo/Dockerfile"
if [ ! -f "$df" ]; then
  warn "no Dockerfile - devcontainer/Railway/swarm workflow need one with stages 'tools' and 'full' (see README)"
else
  grep -qiE '^FROM .* AS tools\b' "$df" || warn "Dockerfile: no 'tools' stage (devcontainer + CI image)"
  last="$(grep -iE '^FROM ' "$df" | tail -1)"
  echo "$last" | grep -qiE ' AS full\b' || warn "Dockerfile: last stage is not 'full' (Railway builds the last stage): $last"
  grep -q 'WITH_CLAUDE' "$df" || warn "Dockerfile: no ARG WITH_CLAUDE (Claude Code CLI for swarm runs)"
  grep -q 'docker/entrypoint.sh' "$df" || warn "Dockerfile: ENTRYPOINT is not docker/entrypoint.sh"
fi
echo "sync: kit $ver installed in $repo"
