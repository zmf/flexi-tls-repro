FROM node:20-bookworm-slim

WORKDIR /app

ENV NPM_CONFIG_UPDATE_NOTIFIER=false

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl \
  && update-ca-certificates \
  && rm -rf /var/lib/apt/lists/*


COPY package.json ./
RUN npm install

COPY fastly.toml ./
COPY webpack.config.cjs ./
COPY run-repro.sh ./
COPY run-repro-online.sh ./
COPY entrypoint.sh ./
COPY src ./src

RUN chmod +x /app/run-repro.sh /app/run-repro-online.sh /app/entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]