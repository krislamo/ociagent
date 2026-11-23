# ociagent

Run coding agents in a Debian OCI image under rootless Podman. The
launcher mounts selected workspace paths read-only and runs each session in a
libkrun microVM by default.

## Requirements

- Bash 4.4+
- GNU coreutils and GNU findutils
- Rootless Podman
  - `podman-compose` OR
  - Docker CLI and Compose plugin with the Podman socket
- For microVMs, crun with libkrun
  - `+LIBKRUN` in `podman info`
  - read/write access to `/dev/kvm`

## Quick start

1. Build the agent images from your ociagent checkout

   With the Docker CLI connected to Podman, run

   ```sh
   docker compose build
   ```

   **OR** use Podman's Compose command

   ```sh
   podman compose build
   ```

2. Symlink the checkout's executable into a local directory on your `PATH`

   If `~/.local/bin` is on your `PATH`, run

   ```sh
   ln -s "$PWD/ociagent" ~/.local/bin/ociagent
   ```

   - `ociagent` follows it's symlink to the checkout for its configuration

3. Start a session from your project directory

   e.g.,
   ```sh
   ociagent -a claude
   ```

   **OR** create and use a workspace from your ociagent checkout, e.g.,

   ```sh
   mkdir -p workspaces/myproject
   ociagent -a codex -w workspaces/myproject
   ```

## Options

| Option                     | Behavior                                       |
| -------------------------- | ---------------------------------------------- |
| `-a`, `--agent`            | Select `claude` or `codex` (required)          |
| `-w`, `--workspace PATH`   | Relative to current directory (default `.`)    |
| `-n`, `--notes PATH`       | Mounts a separate directory at `/notes`        |
| `-i`, `--insecure`         | Runs a plain container                         |
| `-c`, `--cpus CPUS`        | MicroVM vCPUs (krun only, default `2`)         |
| `-r`, `--ram MIB`          | MicroVM RAM in MiB (krun only, default `2048`) |
| `-p`, `--protect PATTERNS` | Replaces the read-only name patterns           |
| `-- AGENT_ARGS...`         | Passes subsequent arguments to the agent       |
| `-h`, `--help`             | Prints usage                                   |
| `-v`, `--version`          | Prints the launcher version                    |

### Workspace and notes

Workspaces inside the checkout must be subdirectories of `workspaces/`.

Notes default to `notes/<workspace-name>` in the checkout, using the basename
of the resolved workspace. Use `-n` to keep separate notes for workspaces
with the same name.

Relative `-n` paths resolve from the directory where you run `ociagent`.
Notes inside the checkout must be subdirectories of `notes/`.

### Protected paths

The default patterns match at any depth in the workspace.

```text
.git .venv venv .vscode .idea .devcontainer .envrc *.code-workspace
```

Pass `--protect` one quoted, space-separated list to replace the defaults.

```sh
ociagent -a claude -w ~/src/myrepo --protect '.git .env'
```

## Configuration

Compose reads `.env` in the checkout. Relative paths in the table resolve
from that checkout.

| Variable                       | Default and purpose                        |
| ------------------------------ | ------------------------------------------ |
| `CONFIG`                       | `./config/claude` (config and credentials) |
| `CLAUDE_MD`                    | `./claude/CLAUDE.md` (user instructions)   |
| `MANAGED_SETTINGS_D`           | `./claude/managed-settings.d` (drop-ins)   |
| `CODEX_CONFIG`                 | `./config/codex` (config and credentials)  |
| `AGENTS_MD`                    | `./codex/AGENTS.md` (user instructions)    |
| `TZ`                           | `America/New_York` (container time zone)   |
| `OCIAGENT_UID`, `OCIAGENT_GID` | `1000` each (container UID and GID)        |

Rebuild after changing `OCIAGENT_UID` or `OCIAGENT_GID`.

Claude enables its Bash sandbox. Read-only `*.json` drop-ins can add or
override managed settings at launch. Codex allows `read-only` and
`workspace-write` and defaults to `workspace-write`. Both allow sandboxed
writes to `/notes` by default.

### Override agent instructions

For Claude, run this from the checkout

```sh
cp claude/CLAUDE.md claude/CLAUDE.local.md
```

In `.env`, set

```dotenv
CLAUDE_MD=./claude/CLAUDE.local.md
```

**OR** for Codex, run this from the checkout

```sh
cp codex/AGENTS.md codex/AGENTS.local.md
```

In `.env`, set

```dotenv
AGENTS_MD=./codex/AGENTS.local.md
```

Edit your local copy. Both local files are gitignored.

## Protection limits

- Read-only mounts cover paths found at launch. A `.git` created during a
  session is writable and can configure hooks that host Git runs. Nested
  mounts can be bypassed by renaming an ancestor. Run one session per
  workspace at a time.
  Launch fails if a protected path is a symlink, its path contains `'`,
  `$`, `:`, a newline or a carriage return, or the workspace scan fails
- The workspace outside protected mounts, notes, and agent config are writable.
  Each agent's config, credentials and history are shared across its workspaces.
  Container networking is unrestricted
- Bare `docker compose run --rm -e OCIAGENT_KRUN=0 claude` mounts
  `./workspaces` at `/workspaces` by default and skips launcher protections
  and the microVM

## Updates

To upgrade Codex, change `CODEX_VERSION` in `codex/Dockerfile` before
rebuilding.

From the checkout, use the Docker CLI connected to Podman

```sh
docker pull debian:trixie-slim &&
docker compose build --no-cache
```

**OR** use Podman directly

```sh
podman pull debian:trixie-slim &&
podman compose build --no-cache
```

## License

[0BSD](LICENSE)
