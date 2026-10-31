# Tokens and secrets

Nothing secret is stored in this repo, a DV repo, an image, a log or a chat. Each credential is created by the owner
and pasted only into a secret store.

| credential | create it | where it goes | used by |
|---|---|---|---|
| `CLAUDE_CODE_OAUTH_TOKEN` | `claude setup-token` on your own machine (browser login, prints a long-lived token billed to your Claude subscription) | GitHub **repo secret** (each DV repo), **Codespaces secret** (once, tick the repos), **Railway service variable** (swarm services) | `docker/swarm.sh` — all three run targets |
| `GITHUB_TOKEN` (Railway only) | **fine-grained PAT**: Settings → Developer settings → Fine-grained tokens; *Only select repositories* (that repo); permission **Contents: Read and write**, nothing else; expiry ≤ 90 days | Railway service variable | `docker/publish_metrics.sh` pushes `metrics-data` |
| Railway ↔ GitHub link | reconnect from Railway; on GitHub's install screen choose **Only select repositories** | GitHub App installation (not a token) | Railway deploys from the repo |

Actions and Codespaces inject their own `GITHUB_TOKEN`; don't create one for them. `ANTHROPIC_API_KEY` works in place
of `CLAUDE_CODE_OAUTH_TOKEN` (pay-as-you-go Console billing instead of the subscription).

## Setting the Actions secret in every DV repo at once
Personal accounts have no account-wide Actions secrets. With `gh` logged in (`gh auth login`), run this locally;
the token is read from the terminal, never echoed or written to history:
```bash
read -rs TOK
for r in $(cat dv-repos.txt); do printf %s "$TOK" | gh secret set CLAUDE_CODE_OAUTH_TOKEN -R "markrthomas/$r"; done
unset TOK
```
(`dv-repos.txt`: one repo name per line — the repos `sync.sh` has been run on.)

## After a provider security incident (e.g. Railway, 2026)
1. GitHub → Settings → Applications: review **Installed GitHub Apps** and **Authorized OAuth Apps**; remove the old
   Railway grants. Developer settings → tokens: delete any PAT that was given to the provider.
2. Delete the old variables on every Railway service before adding fresh ones.
3. Mint **new** tokens (never reuse old values), scoped as in the table, with an expiry.
4. Protect `main` in each repo (branch ruleset: no direct pushes, no force-push, no deletion) so no token can write it;
   the kit only ever pushes `swarm/*` and `metrics-data`.
5. Rotate on a schedule (90 days) and whenever a token may have been exposed.
