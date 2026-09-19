#!/usr/bin/env bash
# Scan des vulnérabilités des images Docker (Trivy) au format Prometheus textfile.
# Les métriques sont relues par node_exporter (--collector.textfile.directory).
#   trivy_vulnerabilities_total{image,severity}
#   trivy_scan_success{image}
#   trivy_scan_time_seconds
set -uo pipefail

OUT=/opt/node_exporter/textfile/trivy.prom
TMP="${OUT}.tmp"

if [ ! -s /opt/trivy/images.list ]; then
  echo "Pas d'images à scanner" >&2
  exit 0
fi

start=$(date +%s)
: > "$TMP"

while IFS= read -r image; do
  [ -z "$image" ] && continue
  dirty=$(echo "$image" | tr '/:' '_')
  # Scan hors ligne, sans mise à jour de la base, résultats JSON
  docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /opt/trivy/cache:/root/.cache \
    aquasec/trivy:0.52.2 image --scanners vuln --no-progress --ignore-unfixed \
    --severity UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL --format json "$image" \
    > /tmp/trivy-${dirty}.json 2>/dev/null

  if [ $? -ne 0 ] || [ ! -s /tmp/trivy-${dirty}.json ]; then
    echo "trivy_scan_success{image=\"$image\"} 0" >> "$TMP"
    continue
  fi

  python3 - "$image" /tmp/trivy-${dirty}.json >> "$TMP" <<'PY'
import json, sys
image, path = sys.argv[1], sys.argv[2]
try:
    with open(path) as f:
        data = json.load(f)
except Exception:
    print(f'trivy_vulnerabilities_total{{image="{image}",severity="PARSE_ERROR"}} 0')
    sys.exit(0)
counts = {"UNKNOWN": 0, "LOW": 0, "MEDIUM": 0, "HIGH": 0, "CRITICAL": 0}
for result in data.get("Results", []):
    for vuln in result.get("Vulnerabilities", []):
        sev = vuln.get("Severity", "UNKNOWN")
        if sev in counts:
            counts[sev] += 1
for sev, n in counts.items():
    print(f'trivy_vulnerabilities_total{{image="{image}",severity="{sev}"}} {n}')
PY
  echo "trivy_scan_success{image=\"$image\"} 1" >> "$TMP"
  rm -f /tmp/trivy-${dirty}.json
done < /opt/trivy/images.list

elapsed=$(($(date +%s) - start))
echo "trivy_scan_time_seconds $elapsed" >> "$TMP"
mv "$TMP" "$OUT"