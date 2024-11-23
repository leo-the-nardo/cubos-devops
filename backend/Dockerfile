FROM node:22.11.0-bullseye

WORKDIR /app
COPY package*json .
RUN npm install 
COPY instrumentation.mjs .
COPY index.js .

CMD ["node", "--import", "./instrumentation.mjs", "index.js"]
# CMD ["node", "--require", "@opentelemetry/auto-instrumentations-node/register", "index.js"]