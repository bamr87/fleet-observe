#!/usr/bin/env bash
# validate.sh: check the stack's configs without starting it, using the images compose.yml
# pins (issue #1, FOBS-001). The image refs are read from compose.yml, so a version bump
# there is the only bump.
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/validate.sh [-h|--help]

Validate the stack's configs without starting it, with the images compose.yml pins:

  compose.yml                 docker compose config -q
  otel/config.yaml            otelcol-contrib validate (the collector image)
  prometheus/prometheus.yml   promtool check config (the Prometheus image)

Runs every check, names each file that failed and exits 1 if any did.
Needs docker with compose v2 and jq; the first run pulls the pinned images.
GRAFANA_ADMIN_PASSWORD may be unset: the compose check supplies a placeholder,
and scripts/check_compose.py is what enforces that the password is required.
EOF
}

case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
  "") ;;
  *)
    echo "validate: unknown argument: $1 (see --help)" >&2
    exit 2
    ;;
esac

cd "$(dirname "${BASH_SOURCE[0]}")/.."

for tool in docker jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "validate: FAIL: $tool is required but not installed" >&2
    exit 1
  fi
done

failed=()

# compose.yml requires GRAFANA_ADMIN_PASSWORD (`:?`); a placeholder lets the syntax check run without one.
if GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-validate-placeholder}" docker compose config -q; then
  echo "validate: ok: compose.yml"
else
  failed+=("compose.yml")
fi

# The image a service runs, read without interpolation: needs no password and no .env.
image_of() {
  local ref
  ref="$(docker compose config --no-interpolate --format json | jq -r --arg svc "$1" '.services[$svc].image // empty')" || return 1
  if [[ -z "$ref" || "$ref" == *'$'* ]]; then
    echo "validate: compose.yml has no literal image for service $1" >&2
    return 1
  fi
  printf '%s\n' "$ref"
}

# The collector loads the config the way it would at startup: an unknown component, or a
# pipeline that references one that is not configured, fails here.
if otel_image="$(image_of otel-collector)" &&
  docker run --rm --quiet \
    -v "$PWD/otel/config.yaml:/etc/otelcol/config.yaml:ro" \
    "$otel_image" validate --config=/etc/otelcol/config.yaml; then
  echo "validate: ok: otel/config.yaml ($otel_image)"
else
  failed+=("otel/config.yaml")
fi

# promtool check config also checks every file prometheus.yml lists under rule_files. When the
# alerting rules land (FOBS-005), add `promtool check rules` here for any rule file it does not list.
if prom_image="$(image_of prometheus)" &&
  docker run --rm --quiet --entrypoint promtool \
    -v "$PWD/prometheus:/p:ro" \
    "$prom_image" check config /p/prometheus.yml; then
  echo "validate: ok: prometheus/prometheus.yml ($prom_image)"
else
  failed+=("prometheus/prometheus.yml")
fi

if ((${#failed[@]})); then
  echo "validate: FAIL: ${failed[*]}" >&2
  exit 1
fi
echo "validate: ok: compose, collector and Prometheus configs are valid"
