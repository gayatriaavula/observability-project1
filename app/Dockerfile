FROM node:20-alpine AS base
WORKDIR /usr/src/app

# Pick up patched Alpine OS packages (e.g. openssl) not yet baked into the
# node:20-alpine base image tag at build time.
RUN apk upgrade --no-cache

COPY package.json ./
RUN npm install --omit=dev --no-audit --no-fund && \
    npm cache clean --force

COPY src ./src

# The container only ever runs `node`, never `npm` -- drop npm/npx/corepack
# and their bundled node_modules (tar, glob, minimatch, etc.) so known CVEs
# in npm's own internal dependencies don't show up in image scans for code
# that's unreachable at runtime.
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack

# node:20-alpine already ships a non-root "node" user
USER node
EXPOSE 8080

ENV NODE_ENV=production
CMD ["node", "src/index.js"]
