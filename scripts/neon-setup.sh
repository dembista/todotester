#!/usr/bin/env bash
# Crée une base PostgreSQL managée sur Neon et affiche la chaîne DATABASE_URL.
# Prérequis : NEON_API_KEY (https://neon.tech/docs/manage/api-keys) et curl/jq.
# Usage :
#   NEON_API_KEY=... ./scripts/neon-setup.sh [nom-du-projet] [branche]
set -euo pipefail

API="https://console.neon.tech/api/v2"
PROJECT_NAME="${1:-todo-app}"
BRANCH="${2:-main}"

: "${NEON_API_KEY:?NEON_API_KEY manquante - voir https://neon.tech/docs/manage/api-keys}"

echo "Création du projet Neon '$PROJECT_NAME'..."
PROJECT=$(curl -fsS -X POST "$API/projects" \
  -H "Authorization: Bearer $NEON_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"project\":{\"name\":\"$PROJECT_NAME\",\"region_id\":\"aws-eu-west-3\"}}")
PROJECT_ID=$(echo "$PROJECT" | jq -r '.project.id')

echo "Projet : $PROJECT_ID"
BRANCHES=$(curl -fsS "$API/projects/$PROJECT_ID/branches" -H "Authorization: Bearer $NEON_API_KEY")
BRANCH_ID=$(echo "$BRANCHES" | jq -r ".branches[] | select(.name==\"$BRANCH\") | .id")

DATABASE=$(echo "$PROJECT" | jq -r '.connection_uris[0].connection_uri')
echo
echo "== Chaîne de connexion (remplacez :PASSWORD et /neondb) =="
echo "$DATABASE"
echo
echo "Ajoutez-la comme secret GitHub :"
echo "  gh secret set DATABASE_URL -R <owner>/todotester"
echo
echo "Puis injectez-la dans Ansible :"
echo "  ansible-playbook ... --extra-vars app_database_url=\$DATABASE_URL"