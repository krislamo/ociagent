# ociagent

Claude Code in a Debian slim image under rootless Podman, running as
user `claude`. The agent is isolated in a container and can write only to its
own project. Paths that run code on the host and usually sit outside git history
(`.git`, virtualenvs, etc.) are mounted read-only.

## Requirements

Bash 4.4 or newer, AND Podman used through either:

- the docker CLI with the compose plugin, pointed at the Podman socket, i.e.,
  `DOCKER_HOST=unix://$XDG_RUNTIME_DIR/podman/podman.sock`

OR

- `podman compose` with `podman-compose` installed

The compose file uses Podman-only options:

- `userns_mode: keep-id`
- `unmask=/proc/*`

## .env config

| Variable             | Default                | Purpose                              |
| -------------------- | ---------------------- | ------------------------------------ |
| `CONFIG`             | `./config`             | Claude's config and credentials      |
| `CLAUDE_MD`          | `./CLAUDE.md`          | Claude's user CLAUDE.md              |
| `MANAGED_SETTINGS_D` | `./managed-settings.d` | Managed-settings drop-ins, read-only |
| `OCIAGENT_PROTECT`   | see below              | Names mounted read-only              |
| `TZ`                 | `America/New_York`     | Container time zone                  |
| `OCIAGENT_UID`       | `1000`                 | Container UID, rebuild to change     |
| `OCIAGENT_GID`       | `1000`                 | Container GID, rebuild to change     |

**Note:** `ociagent` sources `.env` as bash, so **quote values with spaces**:
`OCIAGENT_PROTECT='.git .env'`. Left unquoted, the rest of the line runs as a
command.

### CLAUDE.md

`CLAUDE.md` is mounted for the agent. To use your own without touching the
tracked file, copy it to `CLAUDE.local.md` (gitignored), edit it, and point
`.env` at it:

```text
cp CLAUDE.md CLAUDE.local.md
echo 'CLAUDE_MD=./CLAUDE.local.md' >> .env
```

### Managed settings

The image ships `managed-settings.json`, which Claude can't override. It turns
on the Bash sandbox and lets sandboxed commands write to `/notes`. To add
host-local managed settings without a rebuild, put `*.json` files in
`managed-settings.d/` (gitignored). They're merged on top of the base and take
effect on the next launch.

**Note:** _A drop-in can't remove base entries_

## Usage

Build your `localhost/claude-code:latest` image:

```text
docker compose build
```

OR

```text
podman compose build
```

### ociagent

From the repo root, run a project in `./workspaces/<project>` at `/<project>`,
with its notes in `./notes/<project>`:

```text
./ociagent myproject [claude args ... e.g., --resume <ID> ]
```

The path works too, so the name can be tab-completed:
`./ociagent workspaces/myproject/`.

Each project gets its own mount point, so Claude keeps separate memory and
session history per project.

These paths are mounted read-only inside the project:

```text
.git .venv venv .vscode .idea .devcontainer .envrc *.code-workspace
```

_Replace_ that list with a space-separated `OCIAGENT_PROTECT`, in the
environment or (quoted) in `.env`:

```text
OCIAGENT_PROTECT='.git .env' ./ociagent myproject
```

The names match at any depth. `ociagent` refuses to launch if a match is a
symlink, if its path contains `'`, `$`, a newline or a carriage return, or if
the project can't be searched completely (e.g., an unreadable directory).

Limits of the protection:

- Only in-scope paths that existed at launch are covered. A `.git` created
  during the session is writable, and git on the host runs what its config
  names: git hooks, `core.fsmonitor`
- `config/` is shared by every project and is writable. Credentials, history and
  memory of one project are readable from another
- The container's network isn't restricted. Only sandboxed Bash commands go
  through Claude Code's proxy
- Run one session per project at a time. A running session can turn a nested
  match into a symlink while a second launch is checking it
- A match at the top of the project can't be moved. A nested one can be
  sidestepped by renaming a directory above it, so treat nested protection as
  best effort
- `docker compose run --rm claude` still works, but mounts all of `./workspaces`
  at `/workspaces` without protections

### Update

```text
docker pull debian:trixie-slim &&
docker compose build --no-cache
```

OR

```text
podman pull debian:trixie-slim &&
podman compose build --no-cache
```

## License

This project is released under the 0BSD license, which allows unrestricted use,
modification, and distribution.
