# Dockerfile contract

Every DV repo's root `Dockerfile` must provide:

1. A stage named **`tools`**: the pinned toolchain only (no repo source), so CI can cache it by tool versions and the
   devcontainer can mount the repo live. It must honour `ARG WITH_CLAUDE=0`:
   ```dockerfile
   ARG WITH_CLAUDE=0
   RUN if [ "$WITH_CLAUDE" = "1" ]; then \
         apt-get update && apt-get install -y --no-install-recommends nodejs npm \
         && npm install -g @anthropic-ai/claude-code && rm -rf /var/lib/apt/lists/*; \
       fi
   ```
2. A **last** stage named **`full`** (Railway builds the last stage; the swarm workflow builds `--target full`):
   ```dockerfile
   FROM tools AS full
   ENV PYTHONUNBUFFERED=1
   WORKDIR /repo
   COPY . /repo
   RUN chmod +x docker/*.sh
   ENTRYPOINT ["/repo/docker/entrypoint.sh"]
   ```
3. `git`, `make`, `python3` and `bash` in `tools` (the kit scripts need them).

`sync.sh` checks these and warns; it never edits a Dockerfile. Reference: `markrthomas/eth-dj-to-pcie-pipe-bridge`.
