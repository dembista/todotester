#!/usr/bin/env bash
# Génère la paire de clés SSH utilisée par :
#   - Terraform (key_name "todo-app" -> paire EC2 importée)
#   - Ansible / CI/CD (secret GitHub DEPLOY_SSH_PRIVATE_KEY = contenu de todo-app.pem)
# Usage : ./scripts/create_keypair.sh
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PEM="$DIR/todo-app.pem"

if [ -f "$PEM" ]; then
  echo "Clé existante : $PEM (on la conserve)"
else
  echo "Génération de la clé privée..."
  ssh-keygen -t ed25519 -f "$PEM" -N "" -C "todo-app-ci"
fi
chmod 600 "$PEM"

echo
echo "== Clé privée générée : $PEM =="
echo "1) Ajoutez son contenu comme secret GitHub DEPLOY_SSH_PRIVATE_KEY :"
echo "   gh secret set DEPLOY_SSH_PRIVATE_KEY -R <owner>/todotester < \"$PEM\""
echo
echo "2) Importez la clé PUBLIQUE comme paire EC2 nommée 'todo-app' (région AWS choisie) :"
PUB=$(sed 's/$/\\n/' "${PEM}.pub" | tr -d '\n')
echo "   aws ec2 import-key-pair --key-name todo-app --public-key-material \"$PUB\""
echo
echo "3) Le CI pourra alors se connecter aux instances EC2 créées par Terraform."