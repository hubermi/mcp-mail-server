# syntax=docker/dockerfile:1

# Runs the published npm package exactly like the documented MCP client setup:
#   npx -y mcp-mail-server
# Requires Node.js 22.13.0 or newer.
#
# Transport is selected with MCP_TRANSPORT:
#   stdio          (default) talk JSON-RPC over stdin/stdout; run with `-i`
#   streamableHttp serve MCP over HTTP at http://<host>:${MCP_PORT}/mcp
#   sse            serve MCP over SSE at http://<host>:${MCP_PORT}/sse
# HTTP/SSE use supergateway to bridge the stdio server.
FROM node:22-alpine

# Version of the mcp-mail-server npm package to bake into the image.
ARG MCP_MAIL_SERVER_VERSION=latest
# Version of supergateway (stdio -> HTTP/SSE bridge).
ARG SUPERGATEWAY_VERSION=4.1.0

ENV NODE_ENV=production \
  NPM_CONFIG_UPDATE_NOTIFIER=false \
  MCP_TRANSPORT=stdio \
  MCP_PORT=8000

# Pre-install the package so `npx -y mcp-mail-server` starts instantly and
# works without network access to the npm registry at runtime.
RUN npm install -g \
    "mcp-mail-server@${MCP_MAIL_SERVER_VERSION}" \
    "supergateway@${SUPERGATEWAY_VERSION}" \
  && npm cache clean --force

# Default location for attachment downloads/uploads; mount a volume here and
# set MAIL_ALLOWED_ROOTS=/data to enable local attachment access.
RUN mkdir -p /data && chown node:node /data

COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

USER node
WORKDIR /home/node

# Only used when MCP_TRANSPORT is streamableHttp or sse.
EXPOSE 8000

# docker-entrypoint.sh validates the configuration, then runs
# `npx -y mcp-mail-server` directly (stdio) or behind supergateway (HTTP/SSE).
ENTRYPOINT ["docker-entrypoint.sh"]
