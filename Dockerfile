FROM node:20-alpine AS deps
WORKDIR /app

COPY package*.json ./
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi

FROM node:20-alpine AS builder
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=7860
ENV HOSTNAME=0.0.0.0

RUN apk add --no-cache fontconfig ttf-dejavu ttf-freefont font-noto

# HF Spaces runs as user 1000
RUN addgroup -g 1000 appgroup && adduser -u 1000 -G appgroup -D appuser

# Standalone output
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

# Directory data con permessi corretti
RUN mkdir -p /app/data && chown -R appuser:appgroup /app

USER appuser

EXPOSE 7860
CMD ["node", "server.js"]
