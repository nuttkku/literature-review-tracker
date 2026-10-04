# ── Build stage: compile the Svelte UI into dist/ ─────────────────────────────
FROM node:26-alpine AS build

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build

# ── Production stage ──────────────────────────────────────────────────────────
# A Node server (not a static host) is required: sign-in, 2FA and user management read and write
# the user store at runtime.
FROM node:26-alpine AS prod

# Pick up OS security patches (e.g. OpenSSL) released after the base image was published.
RUN apk update && apk upgrade --no-cache

WORKDIR /app
ENV NODE_ENV=production
ENV PORT=80
ENV STATE_DIR=/app/state

COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY server ./server
# The example corpus, served only through the authenticated /api/app-data route and never bundled
# into dist/. docker-compose.yml mounts your own ./data over it.
COPY data ./data
COPY --from=build /app/dist ./dist

# Run as the unprivileged "node" user (uid 1000), not root. Port 80 needs no extra capability in
# Docker because the published port is mapped by the daemon.
RUN mkdir -p /app/state /app/papers && chown -R node:node /app
USER node

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s CMD wget -qO- http://localhost/api/health || exit 1

CMD ["node", "server/index.js"]
