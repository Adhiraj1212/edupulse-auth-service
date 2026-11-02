FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY . .
USER node
EXPOSE 4000
# ECS ignores this; copy the same command into the task definition's healthCheck.
HEALTHCHECK --interval=10s --timeout=3s --retries=6   CMD wget -qO- http://127.0.0.1:4000/health || exit 1
CMD ["node", "index.js"]
