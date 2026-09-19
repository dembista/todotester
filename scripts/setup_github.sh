#!/usr/bin/env bash
# Configure le dépôt GitHub pour le projet todotester :
#  1. Crée le dépôt (si absent, sinon réutilise l'existant)
#  2. Secrets : DOCKERHUB_USERNAME, DOCKERHUB_TOKEN, DEPLOY_SSH_PRIVATE_KEY, DATABASE_URL
#  3. Variables : DEV_HOST, PROD_HOST, SONAR_HOST_URL
#  4. Protection de la branche main (bloque les push directs)
# Utilisateur GitHub : dembista.
set -euo pipefail

REPO="dembista/todotester"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Toutes les valeurs fournies en ENV ne doivent JAMAIS être commitées.
TOKEN_GH=${TOKEN_GH:-}
NEON_URL=${NEON_URL:-}
SSH_KEY=${SSH_KEY:-"$DIR/todo-app.pem"}
export GH_TOKEN="${TOKEN_GH:-$GH_TOKEN}"

# 1) Dépôt
if gh repo view "$REPO" >/dev/null 2>&1; then
  echo "Dépôt existant : $REPO"
else
  echo "Création du dépôt privé $REPO..."
  gh repo create "$REPO" --private --source "$DIR" --remote origin --description "Todo app — CI/CD + infra EC2 (Terraform/Ansible) + monitoring (Prometheus/Grafana/SonarQube) + DuckDNS"
fi

# 2) Secrets
echo "Configuration des secrets..."
if [ -n "${DOCKERHUB_USERNAME:-}" ]; then gh secret set DOCKERHUB_USERNAME -R "$REPO" --body "$DOCKERHUB_USERNAME"; fi
if [ -n "${DOCKERHUB_TOKEN:-}" ]; then gh secret set DOCKERHUB_TOKEN -R "$REPO" --body "$DOCKERHUB_TOKEN"; fi
if [ -n "${NEON_URL:-}" ]; then gh secret set DATABASE_URL -R "$REPO" --body "$NEON_URL"; fi
if [ -f "$SSH_KEY" ]; then gh secret set DEPLOY_SSH_PRIVATE_KEY -R "$REPO" < "$SSH_KEY"; fi

# 3) Variables (IP des serveurs EC2)
gh variable set DEV_HOST  -R "$REPO" --body "${DEV_HOST:-}"
gh variable set PROD_HOST -R "$REPO" --body "${PROD_HOST:-}"
gh variable set SONAR_HOST_URL -R "$REPO" --body "${SONAR_HOST_URL:-https://madakhoun.duckdns.org/sonarqube}"

# 4) Protection de main
gh api "repos/$REPO/branches/main/protection" \
  --method PUT --input "$DIR/scripts/main-protection.json"

echo "Dépôt $REPO prêt : secrets, variables et protection main configurés."