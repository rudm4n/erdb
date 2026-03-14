FROM node:20-slim AS deps
WORKDIR /app

COPY package*.json ./
COPY scripts/ ./scripts/
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi

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
