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
# Copy the built app, then prune to production dependencies IN PLACE.
#
# Order matters and used to be wrong: this stage installed with --omit=dev and the
# very next line copied /app from the build stage, which overwrote that with the
# build stage's full node_modules -- devDependencies included. The result was the opposite
# of the intent: jest and its transitive deps shipped to production, and the Trivy
# image gate then blocked on CVEs in packages that never run (observed live:
# app/node_modules/test-exclude/... flagged, a jest dependency).
COPY --from=build /app ./
RUN npm prune --omit=dev && npm cache clean --force
# Run as a non-root user.
RUN addgroup -S app && adduser -S app -G app && chown -R app:app /app
USER app
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -q -O- "http://127.0.0.1:3000/healthz" || exit 1
CMD ["bundle","exec","puma","-C","config/puma.rb"]
