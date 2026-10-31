# dv-swarm-kit

The shared Claude Code **agent swarm + run environment** for Mark Thomas's RTL/DV repositories. One copy of the
agents, skills, permissions, swarm launcher, batch entrypoint, results publisher, devcontainer, Railway config and
swarm workflow — vendored into each DV repo by `sync.sh`, configured per repo by a single profile, `.claude/swarm.env`.

Canonical origin: the swarm built in `markrthomas/eth-dj-to-pcie-pipe-bridge` (Oct 2026), made repo-agnostic.

## Layout
| path | what |
|---|---|
| `kit/` | files copied verbatim into every DV repo (kit-owned: change them here, never in a repo) |
| `templates/swarm.env.example` | the per-repo profile; `sync.sh` creates it once, the repo owns it after that |
| `templates/CLAUDE-swarm.md` | the block `sync.sh` keeps current inside each repo's `CLAUDE.md` |
| `.github/workflows/swarm-run.yml` | reusable workflow every repo's `swarm.yml` calls (`@v0`) |
| `sync.sh` | install / update / `--check` drift in a repo checkout |
| `docs/` | tokens + secrets setup, Dockerfile contract |

## What a repo gets
- **Swarm A** (verification): `swarm-manager` → one `dv-env-tester` per `DV_ENVS` entry, `infra-agent`, `dv-runner`.
- **Swarm B** (random regression): `rr-manager` → `rr-runner`, `rr-triage`, `rr-debugger` (opus), `rr-test-author`.
  Repos without a random regression start at `RR_STATUS=bootstrap`; Swarm B builds the flow first (`rr-bootstrap` skill).
- Skills: `board-report`, `mutation-check`, `rr-bootstrap`. Status board: `tools/swarm/board.py` (`make board`).
- Make targets (`swarm.mk`): `swarm`, `swarm-rr`, `swarm-dry`, `batch`, `board`, `heavy T=..`, `swarm-profile`, `swarm-kit-check`.
- Run targets: GitHub Actions (`swarm.yml` → `swarm-run.yml`), Codespaces (`.devcontainer/`), Railway (`railway.toml`).

## Using it
```bash
git clone https://github.com/markrthomas/dv-swarm-kit
./dv-swarm-kit/sync.sh ../my-ip-repo          # install / update
./dv-swarm-kit/sync.sh --check ../my-ip-repo  # drift report only
```
Then in the repo: fill in `.claude/swarm.env`, make the Dockerfile meet `docs/dockerfile.md`, `make swarm-kit-check`,
`make swarm-dry`, commit on a `swarm/` branch, open a PR.

Changing the kit: edit `kit/`, merge, tag `v0.N.0` and move `v0` (`git tag -f v0 && git push -f origin v0`; repos call
`swarm-run.yml@v0`), then `sync.sh` each repo and open PRs. `v0` = still settling; `v1` once the rollout is proven.

Credentials: see [`docs/tokens.md`](docs/tokens.md). Nothing secret is ever stored in this repo or in a DV repo.
