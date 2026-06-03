FROM node:20-alpine AS build
WORKDIR /app

COPY package.json ./
RUN npm install

COPY . .
RUN npm run build

FROM node:20-alpine AS runtime
WORKDIR /app

COPY package.json ./
RUN npm install --omit=dev

COPY --from=build /app/dist ./dist
COPY server ./server

ENV PORT=3000 BACKEND_URL="" BACKEND_SCOPE=""
EXPOSE 3000

CMD ["node", "server/index.js"]
