#!/bin/sh
# Fail fast with a readable message instead of Node's minified stack trace
# when required configuration is missing.
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

exec npx -y mcp-mail-server "$@"
