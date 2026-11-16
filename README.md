# fleet-observe

> Observability stack for the bamr87 fleet: OpenTelemetry Collector, Prometheus and Grafana, wired for every fleet service.

Metrics, traces and dashboards for the whole fleet from one compose file, ready to move onto the fleet-infra cluster.

**Status:** foundation (phase 1). Part of the [bamr87 fleet](https://github.com/bamr87/bamr87).

## Goals

- Run OTel Collector + Prometheus + Grafana locally with one command
- Instrument fleet services with OTLP
- Ship dashboards and alerts as code

## Skills learned

- OpenTelemetry (collector pipelines, OTLP)
- PromQL and alerting rules
- Grafana provisioning as code
- SLOs and observability design

## Fleet tie-in

Collects telemetry from ragio-ai, fredgar-ai, law-ai and the hub's fleet activity log; complements the hub's ELK kit.

## Quick start

You need Docker with Compose v2, plus `curl` and `jq` for the scripts.

```bash
cp .env.example .env              # then set GRAFANA_ADMIN_PASSWORD in .env
scripts/validate.sh               # compose, collector and Prometheus configs, with the images compose.yml pins
docker compose up -d --wait       # returns once Prometheus and Grafana report healthy
scripts/smoke.sh                  # an OTLP metric reaches Prometheus, in a separate throwaway project
```

- `scripts/validate.sh` runs `docker compose config -q`, then `otelcol-contrib validate` on `otel/config.yaml` and `promtool check config` on `prometheus/prometheus.yml`, in the images compose.yml pins. It names each file that fails.
- `docker compose up -d --wait` starts Grafana only after Prometheus is healthy, and fails if a service does not become healthy.
- `scripts/smoke.sh` starts its own compose project (`fobs-smoke`), checks the collector's health endpoint, posts one OTLP/HTTP gauge with a unique name and waits until Prometheus returns that metric by name. Then it removes that project and its volumes; your own stack is a different project, so it and its data are never touched. `--keep` leaves the smoke project running, and `--no-up` probes a project that is already up, named by `SMOKE_PROJECT` (`scripts/smoke.sh --help`).
- `python3 scripts/check_compose.py` checks that every port stays loopback-only and that the Grafana password stays required.

CI runs `validate.sh`, `check_compose.py` and `smoke.sh` (which does the `up --wait`) on every pull request.

Every published port binds `127.0.0.1` only. Each host port can be changed in `.env`; if another stack already holds a default, set a free one there (or export it before `scripts/smoke.sh`).

| Variable | Default | Serves |
| --- | --- | --- |
| `OTEL_GRPC_PORT` | `4317` | OTel Collector, OTLP gRPC |
| `OTEL_HTTP_PORT` | `4318` | OTel Collector, OTLP HTTP (`/v1/metrics`, `/v1/traces`) |
| `OTEL_HEALTH_PORT` | `13133` | OTel Collector health check |
| `PROMETHEUS_PORT` | `9090` | Prometheus UI and API |
| `GRAFANA_PORT` | `3000` | Grafana |
| `GRAFANA_ADMIN_USER` | `admin` | Grafana admin login |
| `GRAFANA_ADMIN_PASSWORD` | _required_ | Grafana admin password |

Compose refuses to start until `GRAFANA_ADMIN_PASSWORD` is set, so Grafana never runs with its default `admin`/`admin` login, and self sign-up is off. The password takes effect only when the `grafana-data` volume is first created: changing it in `.env` later changes nothing. To change it, run `docker compose exec grafana grafana cli admin reset-admin-password --password-from-stdin` and type the new one, or start over with `docker compose down -v`.

Stop the stack:

```bash
docker compose down               # keeps Prometheus and Grafana data in the prometheus-data and grafana-data volumes
docker compose down -v            # also DELETES those volumes and all their data
```

Remote or cluster exposure belongs to the Helm deployment (FOBS-006), not this compose file.

## How it grows

The roadmap lives in [PRD.md](PRD.md) and [features/features.yml](features/features.yml) (ids `FOBS-NNN`, most `status: planned`). Work arrives as pull requests from the hub's evolution and fan-out loops, the `@claude` handler, or the local `evolve` lane (off until `EVOLVE_ENABLED=true`). A human merges every PR. Rules: [docs/constitution.md](docs/constitution.md) · agent guide: [AGENTS.md](AGENTS.md).

## License

[MIT](LICENSE)
