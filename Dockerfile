FROM node:20-bookworm-slim

WORKDIR /app

# Avoid npm update notifier noise in CI/repro output
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
COPY src ./src

RUN chmod +x /app/run-repro.sh

CMD ["./run-repro.sh"]
