# Build stage
FROM node:24-slim AS build

# Install git + python (needed for native modules + cobalt's git info)
RUN apt-get update && apt-get install -y git python3 make g++ && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

# Copy package files
COPY pnpm-lock.yaml pnpm-workspace.yaml package.json ./
COPY api/package.json api/package.json

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy source
COPY . .

# Initialize a fake git repo so cobalt can read commit info at runtime
RUN git init && \
    git config user.email "build@render.com" && \
    git config user.name "Render Build" && \
    git add -A && \
    git commit -m "render build" --allow-empty

# Build the API (if build script exists)
RUN pnpm --filter=@imput/cobalt-api build || true

# Deploy to production folder
RUN pnpm deploy --filter=@imput/cobalt-api --prod /prod/api

# Runtime stage
FROM node:24-slim AS api

# Install git in runtime too (cobalt calls it at startup)
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

ENV NODE_ENV=production

WORKDIR /app

# Copy built application + the fake .git folder
COPY --from=build --chown=node:node /prod/api /app
COPY --from=build --chown=node:node /app/.git /app/.git

# Fallback env vars
ENV API_URL=https://my-cobalt-api.onrender.com

USER node

EXPOSE 9000

# Cobalt's entry point — find it dynamically
CMD ["sh", "-c", "node src/cobalt.js || node src/index.js || node index.js"]
