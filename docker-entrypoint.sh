#!/bin/sh
set -e

CONFIG_PATH="${PAPERCLIP_CONFIG:-/paperclip/instances/default/config.json}"
CONFIG_DIR="$(dirname "$CONFIG_PATH")"

# Create config directory
mkdir -p "$CONFIG_DIR"

# If no config exists, generate a default one for Railway deployment
if [ ! -f "$CONFIG_PATH" ]; then
  echo "No config found at $CONFIG_PATH — generating default Railway config..."
  
  DEPLOY_MODE="${PAPERCLIP_DEPLOYMENT_MODE:-authenticated}"
  DEPLOY_EXPOSURE="${PAPERCLIP_DEPLOYMENT_EXPOSURE:-public}"
  AUTH_SECRET="${BETTER_AUTH_SECRET:-$(head -c 32 /dev/urandom | base64)}"
  SERVER_PORT="${PORT:-3100}"
  
  cat > "$CONFIG_PATH" <<EOF
{
  "meta": {
    "version": 1
  },
  "server": {
    "host": "0.0.0.0",
    "port": ${SERVER_PORT},
    "deploymentMode": "${DEPLOY_MODE}",
    "deploymentExposure": "${DEPLOY_EXPOSURE}"
  },
  "database": {
    "mode": "embedded-postgres",
    "embeddedPostgresPort": 54329,
    "embeddedPostgresDataDir": "/paperclip/instances/default/pgdata"
  },
  "auth": {
    "baseUrlMode": "auto",
    "sessionMaxAge": 2592000
  },
  "storage": {
    "mode": "local-disk",
    "localDisk": {
      "baseDir": "/paperclip/instances/default/storage"
    }
  },
  "secrets": {
    "mode": "local-encrypted"
  },
  "logging": {
    "level": "info"
  },
  "llm": {}
}
EOF

  chmod 600 "$CONFIG_PATH"
  echo "Config created at $CONFIG_PATH"
fi

# Start the server using paperclipai run (handles bootstrap-ceo auto-generation)
echo "Starting Paperclip with paperclipai run..."
exec node --import ./cli/node_modules/tsx/dist/loader.mjs cli/src/index.ts run --config "$CONFIG_PATH"
