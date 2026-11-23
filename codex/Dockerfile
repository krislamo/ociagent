FROM debian:trixie-slim AS build

ARG CODEX_VERSION=0.171.0
ARG COSIGN_SHA256=c3b4f5410e608af03a5eb0aaac84a4313d8da131248e08ff1759ac70c79d1644
ARG COSIGN_VERSION=2.6.5

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl

RUN curl -fsSL -o /cosign \
      "https://github.com/sigstore/cosign/releases/download/v$COSIGN_VERSION/cosign-linux-amd64" \
 && echo "$COSIGN_SHA256  /cosign" | sha256sum -c - \
 && chmod 755 /cosign

RUN url=https://github.com/openai/codex/releases/download/rust-v$CODEX_VERSION \
 && package=codex-package-x86_64-unknown-linux-musl.tar.gz \
 && curl -fsSL -o /tmp/codex.tar.gz "$url/$package" \
 && curl -fsSL -o /tmp/codex.sigstore "$url/$package.sigstore" \
 && /cosign verify-blob --bundle /tmp/codex.sigstore \
      --certificate-oidc-issuer https://token.actions.githubusercontent.com \
      --certificate-identity "https://github.com/openai/codex/.github/workflows/rust-release.yml@refs/tags/rust-v$CODEX_VERSION" \
      /tmp/codex.tar.gz \
 && mkdir /codex \
 && tar -xzf /tmp/codex.tar.gz -C /codex \
 && test -f /codex/codex-package.json \
 && test -x /codex/bin/codex

FROM debian:trixie-slim

RUN apt-get update \
 && apt-get dist-upgrade -y \
 && apt-get install -y --no-install-recommends \
      bubblewrap ca-certificates file git jq less procps ripgrep \
      shellcheck shfmt socat tzdata \
 && rm -rf /var/lib/apt/lists/*

COPY --from=build /codex /opt/codex
RUN ln -s /opt/codex/bin/codex /usr/local/bin/codex

COPY codex/requirements.toml /etc/codex/requirements.toml
COPY codex/managed_config.toml /etc/codex/managed_config.toml
RUN chmod 755 /etc/codex \
 && chmod 644 /etc/codex/requirements.toml /etc/codex/managed_config.toml

COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/ociagent-init

ENV LANG=C.UTF-8

ARG UID=1000
ARG GID=1000
ENV OCIAGENT_UID=${UID} OCIAGENT_GID=${GID}

RUN groupadd -g ${GID} codex \
 && useradd -m -u ${UID} -g ${GID} -s /bin/bash codex

USER codex

ENV CODEX_HOME=/home/codex/.codex
RUN mkdir -p /home/codex/.codex

WORKDIR /workspaces
ENTRYPOINT ["/usr/local/bin/ociagent-init", "codex"]
