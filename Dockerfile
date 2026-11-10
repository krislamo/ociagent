FROM debian:trixie-slim AS build

ARG CLAUDE_REPO_KEY=31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
 && curl -fsSL https://downloads.claude.ai/keys/claude-code.asc \
      -o /claude-code.asc \
 && keys=$(gpg --show-keys --with-colons /claude-code.asc \
      | awk -F: '/^pub/ {n++} /^fpr/ && !f {f = $10} END {print n ":" f}') \
 && test "$keys" = "1:$CLAUDE_REPO_KEY"

FROM debian:trixie-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY --from=build /claude-code.asc /etc/apt/keyrings/claude-code.asc
COPY claude-code.sources /etc/apt/sources.list.d/claude-code.sources

RUN apt-get update \
 && apt-get dist-upgrade -y \
 && apt-get install -y --no-install-recommends \
      bubblewrap claude-code file git jq less procps ripgrep \
      shellcheck shfmt socat tzdata \
 && rm -rf /var/lib/apt/lists/*

COPY managed-settings.json /etc/claude-code/managed-settings.json
RUN chmod 755 /etc/claude-code \
 && chmod 644 /etc/claude-code/managed-settings.json

ENV LANG=C.UTF-8

ARG UID=1000
ARG GID=1000

RUN groupadd -g ${GID} claude \
 && useradd -m -u ${UID} -g ${GID} -s /bin/bash claude

USER claude

ENV CLAUDE_CONFIG_DIR=/home/claude/.config/claude
RUN mkdir -p /home/claude/.config/claude

WORKDIR /workspaces
ENTRYPOINT ["claude"]
