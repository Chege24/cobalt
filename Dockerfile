# Build stage
FROM node:24-slim AS build

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

# Build the API
RUN pnpm --filter=@imput/cobalt-api build

# Deploy to production folder
RUN pnpm deploy --filter=@imput/cobalt-api --prod /prod/api

# Runtime stage
FROM node:24-slim AS api

ENV NODE_ENV=production

WORKDIR /app

# Copy built application (skip .git — we don't need it)
COPY --from=build --chown=node:node /prod/api /app

# Skip the git-info step by providing a fallback
ENV GIT_COMMIT="render-deploy"
ENV API_URL=https://my-cobalt-api.onrender.com

USER node

EXPOSE 9000

CMD ["node", "src/cobalt.js"]
