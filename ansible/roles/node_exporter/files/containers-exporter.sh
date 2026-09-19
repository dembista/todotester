#!/usr/bin/env bash
# Exporteur Prometheus (format textfile) de l'état des conteneurs Docker :
#   - docker_container_up{name,image}         1 = running, 0 = autre état
#   - docker_container_restarts{name}          nombre de redémarrages
#   - docker_container_health{name}           1 = healthy, 0 = unhealthy/absent
#   - docker_running_containers / docker_total_containers (synthèse)
#   - docker_expected_up{name}                 1 pour les services critiques (redondance)
set -uo pipefail

OUT="/opt/node_exporter/textfile/containers.prom"
TMP="${OUT}.tmp"

# Services critiques attendus (redondance) — à adapter selon l'environnement
EXPECTED=(traefik prometheus grafana todo-app node_exporter cadvisor)
if [ -f /opt/trivy/flags/expected_services ]; then
  EXPECTED=( $(cat /opt/trivy/flags/expected_services) )
fi

running=0
total=0

{
  echo "# HELP docker_container_up 1 si le conteneur est en cours d'exécution"
  echo "# TYPE docker_container_up gauge"
  for name in $(docker ps -a --format '{{.Names}}' 2>/dev/null); do
    state=$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null)
    image=$(docker inspect -f '{{.Config.Image}}' "$name" 2>/dev/null)
    restarts=$(docker inspect -f '{{.RestartCount}}' "$name" 2>/dev/null)
    health=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$name" 2>/dev/null)
    total=$((total + 1))
    if [ "$state" = "running" ]; then
      running=$((running + 1))
    fi
    echo "docker_container_up{name=\"$name\",image=\"$image\"} $([ "$state" = "running" ] && echo 1 || echo 0)"
    echo "# HELP docker_container_restarts Nombre de redémarrages du conteneur"
    echo "# TYPE docker_container_restarts counter"
    echo "docker_container_restarts{name=\"$name\"} ${restarts:-0}"
    echo "docker_container_health{name=\"$name\"} $([ "$health" = "healthy" ] && echo 1 || echo 0)"
  done

  echo "# HELP docker_expected_up Services critiques attendus (redondance)"
  echo "# TYPE docker_expected_up gauge"
  for name in "${EXPECTED[@]}"; do
    up=$(docker ps --format '{{.Names}}' | grep -qx "$name" && echo 1 || echo 0)
    echo "docker_expected_up{name=\"$name\"} $up"
  done

  echo "# HELP docker_running_containers Nombre de conteneurs en cours d'exécution"
  echo "# TYPE docker_running_containers gauge"
  echo "docker_running_containers $running"
  echo "# HELP docker_total_containers Nombre total de conteneurs"
  echo "# TYPE docker_total_containers gauge"
  echo "docker_total_containers $total"
} > "$TMP" 2>/dev/null

mv "$TMP" "$OUT"