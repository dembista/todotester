# todotester

Application **todo** (Node.js/Express) déployée en **production** sur AWS EC2 via un
pipeline complet **Infra-as-Code + CI/CD + monitoring**.

| Couche       | Techno                         | Rôle                                                     |
|--------------|--------------------------------|----------------------------------------------------------|
| Infra        | Terraform                      | 2 instances EC2 (`dev` / `prod`), réseau, DNS            |
| Config       | Ansible                        | Docker, Traefik, SonarQube, Prometheus, Grafana, etc.    |
| Base de données | Neon (PostgreSQL managé)     | Persistance de l'application (`DATABASE_URL`)            |
| App          | Node.js / Express              | Todo app conteneurisée                                   |
| CI/CD        | GitHub Actions                 | Tests → image Docker Hub → déploiement `develop`→dev / `main`→prod |
| Monitoring   | Prometheus + Grafana + Trivy   | État serveur, conteneurs, failles, alertes, redondances  |

```
                     ┌──────────────────────────────────────────────┐
  Internet ─(80/443)─►│  Traefik (reverse-proxy Let's Encrypt)       │
  app.<IP> ou domaine │   ├─ App        : https://madakhoun.duckdns.org/   (racine)
                     │   ├─ Grafana    : .../grafana     (dashboards + alertes)
                     │   ├─ SonarQube  : .../sonarqube   (qualité du code)
                     │   ├─ Prometheus : .../prometheus  (métriques + alertes)
                     │   └─ Dashboard  : .../dashboard    (Traefik UI)
                     └──────────────────┬───────────────────────────┘
                     réseaux Docker internes
        Prometheus ◄── node_exporter (CPU/RAM/disque) + cAdvisor (conteneurs)
                        + exporteur d'état des conteneurs + daemon Docker (9323)
        Trivy      ◄── scan des failles des images (quotidien)
```

## Architecture

```
.
├── terraform/                    # Infra AWS (EC2 dev/prod)
│   ├── main.tf                   # VPC, security group, instance, EIP, Route53
│   ├── variables.tf              # dont volume_size (40 Go en prod pour SonarQube)
│   ├── dev.tfvars / prod.tfvars
├── ansible/
│   ├── inventory/hosts.yml       # IP des serveurs
│   ├── inventory/group_vars/     # all.yml (routage DuckDNS, seuils alertes), prod.yml, dev.yml
│   ├── roles/
│   │   ├── docker/               # Docker Engine + métriques daemon (9323)
│   │   ├── traefik/              # reverse proxy + Let's Encrypt + routage par chemins
│   │   ├── sonarqube/            # SonarQube (LTS) + PostgreSQL 16
│   │   ├── node_exporter/        # métriques hôte + état/redémarrages des conteneurs
│   │   ├── cadvisor/             # métriques conteneurs (CPU/mémoire)
│   │   ├── trivy/                # scan quotidien des failles (métriques Prometheus)
│   │   ├── prometheus/           # collecte + FICHIER D'ALERTES (rules.yml)
│   │   ├── grafana/              # dashboards provisionnés + contact point webhook
│   │   └── duckdns/              # cron de mise à jour de l'IP sur le domaine
│   ├── playbooks/setup.yml       # provisionnement des serveurs
│   └── playbooks/deploy-app.yml  # déploiement de l'app (utilisé par le CI)
├── todo-app/                     # application (src/server.js, src/db.js, public/)
├── .github/workflows/deploy.yml  # pipeline CI/CD
└── scripts/                      # utilitaires GitHub / Neon / clé SSH
```

## Fichier d'alertes (`ansible/roles/prometheus/templates/rules.yml.j2`)

Couvre tout ce qui est demandé (visualisable dans Grafana → Alerting) :

- **État des conteneurs** : `ContainerCritiqueArrete`, `ContainerRedemarragesFrequents`,
  `ContainerNonHealthy`
- **État du serveur** : `HostHighCpuLoad`, `HostHighMemoryUsage`, `HostHighDiskSpaceUsage`,
  `HostHighLoadAverage`, `InstanceDown`
- **Failles** : `FailleCritiqueTrouvee`, `FailleHauteTrouvee`, `ScanFaillesEchoue` (Trivy)
- **Redondances** : `RedondanceDegradee` (nb conteneurs < services critiques attendus)
- **App / Traefik** : `AppTodoInjoignable`, `TraefikTauxErreurs5xx`, `TraefikCertProcheExpiration`

Seuils configurables dans `ansible/inventory/group_vars/all.yml`
(`alert_cpu_threshold`, `alert_mem_threshold`, `alert_disk_threshold`, `alert_load_threshold`).

## Domaine DuckDNS (`madakhoun.duckdns.org`)

DuckDNS **gratuit** n'autorise pas les sous-domaines. Les outils sont donc routés
**par chemins** sur le domaine unique :

| Outil       | URL                                             |
|-------------|-------------------------------------------------|
| App todo    | `https://madakhoun.duckdns.org/`                |
| Grafana     | `https://madakhoun.duckdns.org/grafana`         |
| SonarQube   | `https://madakhoun.duckdns.org/sonarqube`       |
| Prometheus  | `https://madakhoun.duckdns.org/prometheus`      |
| Traefik UI  | `https://madakhoun.duckdns.org/dashboard`       |

> Si vous disposez d'un domaine avec sous-domaines DNS : `domain_wildcard_subdomains: true`
> dans `group_vars/all.yml` (routage par `grafana.`, `sonarqube.`, etc.).

L'IP EC2 est maintenue à jour sur DuckDNS par un **cron toutes les 10 minutes**
(`ansible/roles/duckdns/`) — renseignez `duckdns_token` (compte duckdns.org) dans le vault
ou `group_vars/all.yml`.

## Base de données sur Neon

L'application utilise PostgreSQL (Neon) quand la variable **`DATABASE_URL`** est définie,
sinon retombe en mémoire (dev local / tests).

```bash
# 1) Créer la base Neon et récupérer l'URL (jq requis)
NEON_API_KEY=xxx ./scripts/neon-setup.sh todo-app main
# 2) Exposer l'URL au CI
gh secret set DATABASE_URL -R dembista/todotester
```

## Démarrage rapide

### 0) Prérequis
- `terraform` ≥ 1.5, `ansible` (+ collection `community.docker`), `docker`, `gh` (connecté).
- `./scripts/create_keypair.sh` puis import de la clé publique comme paire EC2 `todo-app`.

### 1) Créer les serveurs (Terraform)
```bash
cd terraform
terraform init
# prod (40 Go de disque pour SonarQube)
terraform workspace new prod || true
AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... terraform apply -var-file=prod.tfvars -auto-approve
# dev
terraform workspace new dev || true
terraform apply -var-file=dev.tfvars -auto-approve
```

### 2) Provisionner les outils (Ansible)
```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventory/hosts.yml playbooks/setup.yml
```

### 3) Configurer GitHub (CI/CD + protection main)
```bash
DOCKERHUB_USERNAME=demba087 \
DOCKERHUB_TOKEN=... \
DEV_HOST=... PROD_HOST=... \
./scripts/setup_github.sh
```
- Secrets : `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `DEPLOY_SSH_PRIVATE_KEY`, `DATABASE_URL`
- Variables : `DEV_HOST`, `PROD_HOST`, `SONAR_HOST_URL`
- **Protection de main** : aucun push direct, PR obligatoire + 1 review, checks requis
  (Tests, Build & push), force-push et suppression bloqués.

### 4) Pipeline
- Push sur `develop` → image `demba087/todo-app:develop` + déploiement sur le serveur **dev**
- Push/merge sur `main` (via PR) → image `demba087/todo-app:main` + déploiement sur **prod**
- Scan SonarQube optionnel (si secrets `sonar_token` + variable `SONAR_HOST_URL` configurés)

## Secrets / variables nécessaires dans le dépôt

| Type     | Nom                      | Valeur                                   |
|----------|--------------------------|------------------------------------------|
| Secret   | `DEPLOY_SSH_PRIVATE_KEY` | contenu de `todo-app.pem`                |
| Secret   | `DOCKERHUB_USERNAME`     | `demba087`                               |
| Secret   | `DOCKERHUB_TOKEN`        | jeton Docker Hub (PAT)                   |
| Secret   | `DATABASE_URL`           | `postgresql://...` (Neon)                |
| Secret   | `sonar_token`            | jeton SonarQube (analyse qualité)        |
| Variable | `DEV_HOST` / `PROD_HOST` | IP publiques des instances EC2           |
| Variable | `SONAR_HOST_URL`         | `https://madakhoun.duckdns.org/sonarqube`|

## Liens / accès

Renseignez `duckdns_token` pour activer la mise à jour automatique de l'IP, puis créez
le CNAME/A chez DuckDNS vers l'IP EC2 ; `Let's Encrypt` est géré automatiquement par Traefik
(HTTP-01). Grafana : `https://madakhoun.duckdns.org/grafana` (admin / `grafana_admin_password`).