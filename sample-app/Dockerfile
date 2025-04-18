FROM node:16-alpine
WORKDIR /app
COPY package.json .
RUN npm install --production
COPY index.js .
ENV PORT=8000
CMD ["node", "index.js"]
