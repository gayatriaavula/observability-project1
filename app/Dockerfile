FROM node:20-alpine AS base
WORKDIR /usr/src/app

COPY package.json ./
RUN npm install --omit=dev --no-audit --no-fund

COPY src ./src

# node:20-alpine already ships a non-root "node" user
USER node
EXPOSE 8080

ENV NODE_ENV=production
CMD ["node", "src/index.js"]
