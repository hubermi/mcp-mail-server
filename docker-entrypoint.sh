#!/bin/sh
# Fail fast with a readable message instead of Node's minified stack trace
# when required configuration is missing, then start the server on the
# transport selected by MCP_TRANSPORT.
set -e

missing=""
for var in IMAP_HOST IMAP_PORT IMAP_SECURE SMTP_HOST SMTP_PORT SMTP_SECURE EMAIL_USER EMAIL_PASS; do
  eval "value=\${$var:-}"
  [ -n "$value" ] || missing="$missing $var"
done

if [ -n "$missing" ]; then
  echo "mcp-mail-server: missing required environment variable(s):$missing" >&2
  echo "Pass them with --env-file / -e (docker run) or env_file (docker compose)." >&2
  exit 1
fi

transport="${MCP_TRANSPORT:-stdio}"
port="${MCP_PORT:-8000}"

case "$transport" in
  stdio)
    exec npx -y mcp-mail-server "$@"
    ;;
  streamableHttp)
    # Stateful: one mail-server process (and IMAP connection) per MCP session.
    set -- --outputTransport streamableHttp --stateful "$@"
    ;;
  sse)
    set -- --outputTransport sse "$@"
    ;;
  *)
    echo "mcp-mail-server: unsupported MCP_TRANSPORT '$transport' (use stdio, streamableHttp or sse)" >&2
    exit 1
    ;;
esac

if [ -n "${MCP_AUTH_TOKEN:-}" ]; then
  # supergateway listens internally; the auth proxy owns the public port and
  # only forwards requests carrying `Authorization: Bearer $MCP_AUTH_TOKEN`.
  internal_port="${MCP_INTERNAL_PORT:-8001}"
  if [ "$internal_port" = "$port" ]; then
    echo "mcp-mail-server: MCP_INTERNAL_PORT must differ from MCP_PORT" >&2
    exit 1
  fi
  exec node /usr/local/lib/mcp-mail-server-docker/auth-proxy.mjs \
    supergateway --stdio "npx -y mcp-mail-server" \
    --port "$internal_port" --healthEndpoint /healthz "$@"
fi

echo "mcp-mail-server: WARNING: MCP_AUTH_TOKEN is not set, the $transport endpoint accepts unauthenticated requests" >&2
exec supergateway --stdio "npx -y mcp-mail-server" \
  --port "$port" --healthEndpoint /healthz "$@"
