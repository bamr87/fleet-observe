#!/usr/bin/env bash
# smoke.sh: prove the stack starts healthy and carries an OTLP metric from the collector to
# Prometheus (issue #3, FOBS-001). It runs in its own compose project, so a developer's stack
# and its volumes are never stopped or deleted.
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/smoke.sh [--keep] [--no-up] [-h|--help]

Start the stack in its own compose project and wait until it reports healthy,
check the collector's health endpoint, post one OTLP/HTTP gauge with a unique
name, then poll Prometheus until that metric appears, by name. On exit the
project is removed with `docker compose down -v`.

  --keep      leave the project running; remove it later with
              docker compose -p fobs-smoke down -v
  --no-up     probe a project that is already running; never start or stop it
  -h, --help  show this help

Environment:
  SMOKE_PROJECT   compose project name (default: fobs-smoke). Unless --keep or
                  --no-up is given, the run ends with `down -v` on it, so never
                  name a project whose data you want to keep.
  SMOKE_TIMEOUT   seconds to wait for Prometheus to return the metric (default: 90)
  GRAFANA_ADMIN_PASSWORD
                  a throwaway value is used when it is unset (the test never logs in)
  OTEL_GRPC_PORT OTEL_HTTP_PORT OTEL_HEALTH_PORT PROMETHEUS_PORT GRAFANA_PORT
                  host ports, read from the environment or .env like any compose run.
                  If your own stack holds the defaults, export free ones first.

Needs docker with compose v2, curl and jq. On failure it exits 1 with a one-line reason.
EOF
}

project="${SMOKE_PROJECT:-fobs-smoke}"
timeout="${SMOKE_TIMEOUT:-90}"
keep=0
start=1
started=0

while (($#)); do
  case "$1" in
    --keep) keep=1 ;;
    --no-up) start=0 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "smoke: unknown argument: $1 (see --help)" >&2
      exit 2
      ;;
  esac
  shift
done

if [[ ! "$timeout" =~ ^[0-9]+$ ]]; then
  echo "smoke: SMOKE_TIMEOUT must be a whole number of seconds, got: $timeout" >&2
  exit 2
fi

cd "$(dirname "${BASH_SOURCE[0]}")/.."

for tool in docker curl jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "smoke: FAIL: $tool is required but not installed" >&2
    exit 1
  fi
done

# compose interpolates the whole file and Grafana requires a password; this project never logs in.
GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-smoke-$RANDOM$RANDOM$RANDOM}"
export GRAFANA_ADMIN_PASSWORD

compose() { docker compose -p "$project" "$@"; }

fail() {
  if ((started && !keep)); then
    echo "smoke: last log lines of project $project:" >&2
    compose logs --no-color --tail 20 >&2 || echo "smoke: (could not read the logs)" >&2
  elif ((started)); then
    echo "smoke: project $project is still running for inspection; remove it with: docker compose -p $project down -v" >&2
  fi
  echo "smoke: FAIL: $*" >&2
  exit 1
}

teardown() {
  if ((started && !keep)); then
    compose down -v --remove-orphans >/dev/null 2>&1 ||
      echo "smoke: WARN: could not remove project $project; run: docker compose -p $project down -v" >&2
  fi
}
trap teardown EXIT
trap 'exit 130' INT TERM

# host:port where the project publishes a container port, e.g. 127.0.0.1:4318. Asking compose
# follows .env, the environment and the defaults exactly as `up` resolved them.
published() {
  local addr
  addr="$(compose port "$1" "$2" 2>/dev/null)" || return 1
  [[ -n "$addr" ]] || return 1
  printf '%s\n' "$addr"
}

if ((start)); then
  echo "smoke: starting project $project (docker compose up -d --wait)"
  started=1
  if ! compose up -d --wait --wait-timeout 180 --quiet-pull; then
    fail "project $project did not come up healthy (compose's error is above; if a host port is taken, export free *_PORT values: see --help)"
  fi
fi

health="$(published otel-collector 13133)" ||
  fail "otel-collector is not running in project $project (nothing published for container port 13133)"
otlp="$(published otel-collector 4318)" ||
  fail "otel-collector is not running in project $project (nothing published for container port 4318)"
prom="$(published prometheus 9090)" ||
  fail "prometheus is not running in project $project (nothing published for container port 9090)"

deadline=$((SECONDS + 30))
until curl -fs -o /dev/null --max-time 5 "http://$health/"; do
  ((SECONDS < deadline)) || fail "the collector health check http://$health/ did not return 2xx within 30s"
  sleep 2
done
echo "smoke: ok: collector health check http://$health/"

metric="fobs_smoke_$(date +%s)_${RANDOM}"
# A gauge with no unit, so the collector's Prometheus exporter keeps the name as posted.
# BSD date has no %N, so the timestamp is whole seconds padded to nanoseconds.
payload="$(jq -cn --arg name "$metric" --arg ts "$(date +%s)000000000" '{
  resourceMetrics: [{
    resource: {attributes: [{key: "service.name", value: {stringValue: "fobs-smoke"}}]},
    scopeMetrics: [{
      scope: {name: "fleet-observe/scripts/smoke.sh"},
      metrics: [{name: $name, description: "fleet-observe smoke test",
                 gauge: {dataPoints: [{asDouble: 1, timeUnixNano: $ts}]}}]
    }]
  }]
}')"
if ! err="$(curl -fsS -o /dev/null --max-time 10 -H 'Content-Type: application/json' \
  --data "$payload" "http://$otlp/v1/metrics" 2>&1)"; then
  fail "the collector did not accept the OTLP/HTTP POST to http://$otlp/v1/metrics: $err"
fi
echo "smoke: posted gauge $metric to http://$otlp/v1/metrics"

# How many series an instant query returns.
series() {
  curl -fsS --max-time 5 --get --data-urlencode "query=$1" "http://$prom/api/v1/query" |
    jq -r '.data.result | length'
}

# Poll until the query returns at least one series; give up at the shared deadline.
deadline=$((SECONDS + timeout))
wait_for() {
  local n
  while :; do
    n="$(series "$1" 2>/dev/null)" || n=0
    [[ "$n" =~ ^[1-9][0-9]*$ ]] && return 0
    ((SECONDS < deadline)) || return 1
    sleep 3
  done
}

# Readiness first. `up` is 1 as soon as Prometheus can scrape the exporter, whether or not any
# OTLP data arrived, so the check that counts is the posted metric's own name.
wait_for 'up{job="otel-collector"} == 1' ||
  fail "Prometheus at http://$prom never scraped the collector: up{job=\"otel-collector\"} was not 1 within ${timeout}s"
wait_for "$metric" ||
  fail "posted $metric, but Prometheus at http://$prom did not return it within ${timeout}s"
echo "smoke: ok: Prometheus returned $metric (http://$prom)"

if ((keep)); then
  echo "smoke: project $project is still running; remove it with: docker compose -p $project down -v"
fi
