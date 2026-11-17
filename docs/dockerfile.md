# Dockerfile contract

Every DV repo's root `Dockerfile` must provide:

1. A stage named **`tools`**: the pinned toolchain only (no repo source), so CI can cache it by tool versions and the
   devcontainer can mount the repo live. It must honour `ARG WITH_CLAUDE=0`:
   ```dockerfile
   ARG WITH_CLAUDE=0
   ARG CLAUDE_CODE_VERSION=2.1.322
   RUN if [ "$WITH_CLAUDE" = "1" ]; then \
         apt-get update && apt-get install -y --no-install-recommends nodejs npm gh \
         && npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} && rm -rf /var/lib/apt/lists/*; \
       fi
   ```
   **Pin everything the image downloads** (supply chain: the image runs with the swarm's tokens): a tag or commit for
   every `git clone` (`VERILATOR_REF`, `YOSYS_REF`, `SBY_REF` - a commit, never `main`), an exact version for every
   `npm install -g` / `pip install`, a version for every release download.  Bump them on purpose, in a PR.
2. A **last** stage named **`full`** (Railway builds the last stage; the swarm workflow builds `--target full`):
   ```dockerfile
   FROM tools AS full
   ENV PYTHONUNBUFFERED=1
   WORKDIR /repo
   COPY . /repo
   RUN chmod +x docker/*.sh
   ENTRYPOINT ["/repo/docker/entrypoint.sh"]
   # optional: keep the old default for plain `docker run <img>`; the entrypoint execs any command it is given
   # CMD ["make", "check"]
   ```
   The repo may live at another path (e.g. `WORKDIR /work`); the entrypoint uses the checkout it sits in, or a
   checkout mounted at `/repo` (the swarm workflow mounts one there so the swarm can push).
3. `git`, `make`, `python3` and `bash` in `tools` (the kit scripts need them); `gh` comes with `WITH_CLAUDE=1` so a
   swarm can open its draft PR.

A repo that keeps its own tuned entrypoint lists `docker/entrypoint.sh` in `KIT_KEEP`; its Dockerfile then only needs
the `tools` stage + `WITH_CLAUDE` for the devcontainer and swarm, and its own ENTRYPOINT must pass `swarm` to
`docker/swarm.sh`.

`sync.sh` checks these and warns; it never edits a Dockerfile. Reference: `markrthomas/eth-dj-to-pcie-pipe-bridge`.

## Railway: prebuilt toolchain image (v0.3.10)
Railway stops any build after ~40 minutes, and compiling Verilator / Yosys(+slang) / SymbiYosys from source can exceed
that whenever its layer cache misses. So Railway never compiles: `railway.toml` builds `docker/Dockerfile.railway`,
which starts `FROM ghcr.io/<owner>/<repo>/dv-tools:tools-main` and only adds the repo. Three pieces:

1. **`docker/Dockerfile.railway`** - seeded by `sync.sh` from `templates/Dockerfile.railway` (image name from `GH_REPO`,
   workdir from the Dockerfile's last `WORKDIR`), then repo-owned. Copy in any `ENV` / `RUN` from the Dockerfile's final
   stage that the batch needs (e.g. `ICARUS_BIN_DIR`, `VL_JOBS`, `chmod` of scripts); leave out what only the swarm
   needs (Node, Claude Code, gh).
2. **CI publishes `tools-main`** - the Dockerfile `tools` stage (toolchain only, **no repo source**) pushed to GHCR and
   re-tagged on pushes to main. With a content-addressed CI image (`dv-tools:tools-<hash>`), add after the push step:
   ```yaml
         - name: Tag the toolchain as tools-main (main only)
           if: github.event_name == 'push' && github.ref == 'refs/heads/main'
           run: |
             set -euo pipefail
             img="${{ steps.meta.outputs.image }}"      # the job's tools-<hash> image
             docker buildx imagetools create -t "${img%:*}:tools-main" "$img"
   ```
   Without one, build and push it: `docker build --target tools -t ghcr.io/${GITHUB_REPOSITORY,,}/dv-tools:tools-main .`
3. **The package is public** (GitHub -> Packages -> dv-tools -> Package settings -> Change visibility). In Package
   settings, first **untick "Inherit access from source repository"**: otherwise a package pushed from a private repo
   follows the repo and goes (back) to private, and Railway's pull fails with `403 Forbidden`. Check from anywhere,
   without logging in (200 = public):
   ```bash
   r=<repo>; t=$(curl -s "https://ghcr.io/token?scope=repository:markrthomas/$r/dv-tools:pull" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
   curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $t" \
     -H "Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.v2+json" \
     "https://ghcr.io/v2/markrthomas/$r/dv-tools/manifests/tools-main"
   ``` Railway cannot
   pull a private base image during a build (Railway staff: "not supported"); private-image deploys need Railway Pro.
   Public is safe only because the `tools` stage holds no repo source - never publish a stage that does `COPY . ...`.

Order for a new Railway repo: merge -> CI green (tools-main exists) -> package public -> Redeploy. The deploy the merge
triggers fails with "not found" until then - expected. Proven 2026-11-16/17 on eth-dj, pcie, ucie2 and axi.
