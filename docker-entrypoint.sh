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
  SERVER_PORT="${PORT:-3100}"
  PUBLIC_URL="${PAPERCLIP_PUBLIC_URL:-https://paperclip-production-1cf5.up.railway.app}"
  NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  
  # Use external postgres when DATABASE_URL is set, otherwise embedded
  if [ -n "$DATABASE_URL" ]; then
    DB_MODE="postgres"
    echo "DATABASE_URL detected — using external PostgreSQL"
  else
    DB_MODE="embedded-postgres"
    echo "No DATABASE_URL — using embedded PostgreSQL"
  fi
  
  cat > "$CONFIG_PATH" <<EOF
{
  "\$meta": {
    "version": 1,
    "updatedAt": "${NOW}",
    "source": "onboard"
  },
  "server": {
    "host": "0.0.0.0",
    "port": ${SERVER_PORT},
    "deploymentMode": "${DEPLOY_MODE}",
    "exposure": "${DEPLOY_EXPOSURE}",
    "allowedHostnames": ["paperclip.railway.internal", "paperclip-production-1cf5.up.railway.app"],
    "serveUi": true
  },
  "database": {
    "mode": "${DB_MODE}",
    "embeddedPostgresPort": 54329,
    "embeddedPostgresDataDir": "/paperclip/instances/default/db"
  },
  "auth": {
    "baseUrlMode": "explicit",
    "publicBaseUrl": "${PUBLIC_URL}",
    "disableSignUp": false
  },
  "storage": {
    "provider": "local_disk",
    "localDisk": {
      "baseDir": "/paperclip/instances/default/data/storage"
    },
    "s3": {
      "bucket": "paperclip",
      "region": "us-east-1",
      "prefix": "",
      "forcePathStyle": false
    }
  },
  "secrets": {
    "provider": "local_encrypted",
    "strictMode": false,
    "localEncrypted": {
      "keyFilePath": "/paperclip/instances/default/secrets/master.key"
    }
  },
  "logging": {
    "mode": "file",
    "logDir": "/paperclip/instances/default/logs"
  },
  "llm": {
    "provider": "openai"
  }
}
EOF

  chmod 600 "$CONFIG_PATH"
  echo "Config created at $CONFIG_PATH"
fi

# Start the server using paperclipai run (handles bootstrap-ceo auto-generation)
# Disable Vite dev middleware in production (paperclipai run auto-enables it
# when it detects the source-path entry, but we need static UI serving)
export PAPERCLIP_UI_DEV_MIDDLEWARE=false
# Auto-apply database migrations (no TTY in container)
export PAPERCLIP_MIGRATION_AUTO_APPLY=true
echo "Starting Paperclip with paperclipai run..."
exec node --import ./cli/node_modules/tsx/dist/loader.mjs cli/src/index.ts run --config "$CONFIG_PATH"
