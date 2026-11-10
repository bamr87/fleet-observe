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

```bash
cp .env.example .env              # then set GRAFANA_ADMIN_PASSWORD in .env
docker compose up -d
python3 scripts/check_compose.py  # ports loopback-only, Grafana password required
```

Every published port binds `127.0.0.1` only; the host port is overridable in `.env`. Compose refuses to start until `GRAFANA_ADMIN_PASSWORD` is set, so Grafana never runs with its default `admin`/`admin` login, and self sign-up is off.

| Variable | Default | Service |
| --- | --- | --- |
| `OTEL_GRPC_PORT` | `4317` | OTel Collector, OTLP gRPC |
| `OTEL_HTTP_PORT` | `4318` | OTel Collector, OTLP HTTP |
| `PROMETHEUS_PORT` | `9090` | Prometheus |
| `GRAFANA_PORT` | `3000` | Grafana |
| `GRAFANA_ADMIN_USER` | `admin` | Grafana admin login |
| `GRAFANA_ADMIN_PASSWORD` | _required_ | Grafana admin password |

Remote or cluster exposure belongs to the Helm deployment (FOBS-006), not this compose file.

## How it grows

The roadmap lives in [PRD.md](PRD.md) and [features/features.yml](features/features.yml) (ids `FOBS-NNN`, most `status: planned`). Work arrives as pull requests from the hub's evolution and fan-out loops, the `@claude` handler, or the local `evolve` lane (off until `EVOLVE_ENABLED=true`). A human merges every PR. Rules: [docs/constitution.md](docs/constitution.md) · agent guide: [AGENTS.md](AGENTS.md).

## License

[MIT](LICENSE)
