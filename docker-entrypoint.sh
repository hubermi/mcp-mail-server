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
    exec supergateway \
      --stdio "npx -y mcp-mail-server" \
      --outputTransport streamableHttp \
      --stateful \
      --port "$port" \
      --healthEndpoint /healthz \
      "$@"
    ;;
  sse)
    exec supergateway \
      --stdio "npx -y mcp-mail-server" \
      --outputTransport sse \
      --port "$port" \
      --healthEndpoint /healthz \
      "$@"
    ;;
  *)
    echo "mcp-mail-server: unsupported MCP_TRANSPORT '$transport' (use stdio, streamableHttp or sse)" >&2
    exit 1
    ;;
esac
