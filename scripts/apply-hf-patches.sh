#!/bin/bash
# apply-hf-patches.sh
# Applies Hugging Face Spaces-specific modifications on top of upstream ERDB code.
# This script is idempotent — safe to run multiple times.

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "=== Applying HF Spaces patches ==="

# ─────────────────────────────────────────────
# 1. Dockerfile — rewrite entirely for HF
# ─────────────────────────────────────────────
echo "[1/4] Writing HF Dockerfile..."
cat > Dockerfile << 'DOCKERFILE'
FROM node:20-slim AS deps
WORKDIR /app

RUN apt-get update && apt-get install -y python3 make g++ && rm -rf /var/lib/apt/lists/*

COPY package*.json ./
RUN npm ci --ignore-scripts=false

FROM node:20-slim AS builder
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM node:20-slim AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=7860
ENV HOSTNAME=0.0.0.0

RUN apt-get update && apt-get install -y fontconfig fonts-dejavu-core fonts-freefont-ttf fonts-noto --no-install-recommends && rm -rf /var/lib/apt/lists/*

# Standalone output di Next.js
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

# Directory data con permessi corretti per HF user
RUN mkdir -p /app/data && chown -R 1000:1000 /app

USER 1000

EXPOSE 7860
CMD ["node", "server.js"]
DOCKERFILE

# ─────────────────────────────────────────────
# 2. README.md — prepend HF YAML frontmatter
# ─────────────────────────────────────────────
echo "[2/4] Adding HF YAML frontmatter to README..."
if ! head -1 README.md | grep -q "^---"; then
  ORIGINAL=$(cat README.md)
  cat > README.md << 'YAMLHEADER'
---
title: RatingCasa2026
emoji: 🎬
colorFrom: blue
colorTo: purple
sdk: docker
app_port: 7860
pinned: false
---

YAMLHEADER
  echo "$ORIGINAL" >> README.md
else
  echo "  (already has YAML frontmatter, skipping)"
fi

# ─────────────────────────────────────────────
# 3. CSP — frame-ancestors for HF iframe
# ─────────────────────────────────────────────
echo "[3/4] Patching CSP frame-ancestors..."
CSP_FILE="lib/contentSecurityPolicy.ts"
if [ -f "$CSP_FILE" ]; then
  sed -i "s|frame-ancestors 'none'|frame-ancestors 'self' https://*.hf.space https://huggingface.co|g" "$CSP_FILE"
else
  echo "  (CSP file not found, skipping)"
fi

# ─────────────────────────────────────────────
# 4. next.config.ts — remove X-Frame-Options
# ─────────────────────────────────────────────
echo "[4/4] Removing X-Frame-Options header..."
CONFIG_FILE="next.config.ts"
if [ -f "$CONFIG_FILE" ]; then
  sed -i "/X-Frame-Options/d" "$CONFIG_FILE"
else
  echo "  (next.config.ts not found, skipping)"
fi

# ─────────────────────────────────────────────
# 5. .dockerignore — ensure .git is excluded
# ─────────────────────────────────────────────
if ! grep -q "^\.git$" .dockerignore 2>/dev/null; then
  echo ".git" >> .dockerignore
fi

echo "=== HF patches applied successfully ==="
