#!/usr/bin/env bash
# Usage:
#   ./scripts/deploy.sh qa       → builds both client+admin, deploys to QA
#   ./scripts/deploy.sh prod     → builds both client+admin, deploys to prod
#   ./scripts/deploy.sh qa client  → only client build to QA
#   ./scripts/deploy.sh qa admin   → only admin build to QA

set -euo pipefail

FLAVOR="${1:-qa}"
SITE="${2:-all}"

# Map flavor to Firebase hosting targets
if [[ "$FLAVOR" == "prod" ]]; then
  CLIENT_TARGET="kiri-wellness-prod"
  ADMIN_TARGET="kiri-wellness-admin"
  FLAVOR_DEFINE="prod"
else
  CLIENT_TARGET="kiri-wellness-qa"
  ADMIN_TARGET="kiri-wellness-qa"   # QA uses the same site for simplicity
  FLAVOR_DEFINE="qa"
fi

PROJECT="kiri-wellness-qa"
BUILD_DIR="build/web"

deploy_client() {
  echo "📦 Building CLIENT (FLAVOR=$FLAVOR_DEFINE, SITE=client)..."
  flutter build web \
    --dart-define=FLAVOR="$FLAVOR_DEFINE" \
    --dart-define=SITE=client \
    --release

  echo "🚀 Deploying CLIENT → $CLIENT_TARGET..."
  firebase deploy \
    --only hosting:"$CLIENT_TARGET" \
    --project "$PROJECT"
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
    --project "$PROJECT"
}

if [[ "$SITE" == "client" ]]; then
  deploy_client
elif [[ "$SITE" == "admin" ]]; then
  deploy_admin
else
  deploy_client
  deploy_admin
fi

echo "✅ Done!"
