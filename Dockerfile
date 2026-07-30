# syntax=docker/dockerfile:1
# Tudovu-generated. Multi-stage, non-root runtime, with a HEALTHCHECK.
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi
COPY . .
RUN npm run build --if-present

FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production PORT=3000
# Install only production dependencies for a slim, lower-CVE runtime image.
COPY package*.json ./
RUN if [ -f package-lock.json ]; then npm ci --omit=dev; else npm install --omit=dev; fi && npm cache clean --force
COPY --from=build /app .
# Run as a non-root user.
RUN addgroup -S app && adduser -S app -G app && chown -R app:app /app
USER app
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -q -O- "http://127.0.0.1:3000/healthz" || exit 1
CMD ["bundle","exec","puma","-C","config/puma.rb"]
