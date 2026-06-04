# Stage 1: Build Vite app
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Stage 2: Production runtime — solo deps de producción + dist/ + server/
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev
COPY --from=build /app/dist ./dist
COPY server/ ./server/
ENV PORT=3000 BACKEND_URL="" BACKEND_SCOPE=""
EXPOSE 3000
CMD ["node", "server/index.js"]
