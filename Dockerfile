# syntax=docker/dockerfile:1

# Runs the published npm package exactly like the documented MCP client setup:
#   npx -y mcp-mail-server
# Requires Node.js 22.13.0 or newer.
FROM node:22-alpine

# Version of the mcp-mail-server npm package to bake into the image.
ARG MCP_MAIL_SERVER_VERSION=latest

ENV NODE_ENV=production

# Pre-install the package so `npx -y mcp-mail-server` starts instantly and
# works without network access to the npm registry at runtime.
RUN npm install -g "mcp-mail-server@${MCP_MAIL_SERVER_VERSION}" \
  && npm cache clean --force

# Default location for attachment downloads/uploads; mount a volume here and
# set MAIL_ALLOWED_ROOTS=/data to enable local attachment access.
RUN mkdir -p /data && chown node:node /data

USER node
WORKDIR /home/node

# The MCP server speaks JSON-RPC over stdio, so run the container with `-i`.
ENTRYPOINT ["npx", "-y", "mcp-mail-server"]
