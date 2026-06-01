#!/usr/bin/env bash
# Usage:
#   ./scripts/deploy.sh qa       → builds both client+admin, deploys QA apps
#   ./scripts/deploy.sh prod     → builds both client+admin, deploys PROD apps
#   ./scripts/deploy.sh all      → builds and deploys all 4 apps
#   ./scripts/deploy.sh qa client  → only client build to QA
#   ./scripts/deploy.sh qa admin   → only admin build to QA

set -euo pipefail

FLAVOR="${1:-qa}"
SITE="${2:-all}"

CLIENT_PROJECT="kiri-wellness-qa"
ADMIN_PROJECT="kiri-wellness-qa"

if [[ "$FLAVOR" == "qa" ]]; then
  CLIENT_TARGET="qa-client"
  ADMIN_TARGET="qa-admin"
  FLAVOR_DEFINE="qa"
  CLIENT_PROJECT="kiri-wellness-qa"
  ADMIN_PROJECT="kiri-wellness-qa"
elif [[ "$FLAVOR" == "prod" ]]; then
  CLIENT_TARGET="prod-client"
  ADMIN_TARGET="prod-admin"
  FLAVOR_DEFINE="prod"
  CLIENT_PROJECT="kiri-wellness-qa"
  ADMIN_PROJECT="kiri-wellness-qa"
fi

deploy_client() {
  echo "📦 Building CLIENT (FLAVOR=$FLAVOR_DEFINE, SITE=client)..."
  flutter build web \
    --dart-define=FLAVOR="$FLAVOR_DEFINE" \
    --dart-define=SITE=client \
    --release

  echo "🚀 Deploying CLIENT → $CLIENT_TARGET..."
  firebase deploy \
    --only hosting:"$CLIENT_TARGET" \
    --project "$CLIENT_PROJECT"
}

deploy_admin() {
  echo "📦 Building ADMIN (FLAVOR=$FLAVOR_DEFINE, SITE=admin)..."
  flutter build web \
    --dart-define=FLAVOR="$FLAVOR_DEFINE" \
    --dart-define=SITE=admin \
    --release

  echo "🚀 Deploying ADMIN → $ADMIN_TARGET..."
  firebase deploy \
    --only hosting:"$ADMIN_TARGET" \
    --project "$ADMIN_PROJECT"
}

deploy_all() {
  echo "🔁 Deploying all apps (qa client/admin + prod client/admin)..."

  FLAVOR_DEFINE="qa"
  CLIENT_TARGET="qa-client"
  ADMIN_TARGET="qa-admin"
  CLIENT_PROJECT="kiri-wellness-qa"
  ADMIN_PROJECT="kiri-wellness-qa"
  deploy_client
  deploy_admin

  FLAVOR_DEFINE="prod"
  CLIENT_TARGET="prod-client"
  ADMIN_TARGET="prod-admin"
  CLIENT_PROJECT="kiri-wellness-qa"
  ADMIN_PROJECT="kiri-wellness-qa"
  deploy_client
  deploy_admin
}

if [[ "$FLAVOR" == "all" ]]; then
  deploy_all
elif [[ "$SITE" == "client" ]]; then
  deploy_client
elif [[ "$SITE" == "admin" ]]; then
  deploy_admin
else
  deploy_client
  deploy_admin
fi

echo "✅ Done!"
