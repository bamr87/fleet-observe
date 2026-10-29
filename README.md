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
docker compose config -q
```

## How it grows

The roadmap lives in [PRD.md](PRD.md) and [features/features.yml](features/features.yml) (ids `FOBS-NNN`, most `status: planned`). Work arrives as pull requests from the hub's evolution and fan-out loops, the `@claude` handler, or the local `evolve` lane (off until `EVOLVE_ENABLED=true`). A human merges every PR. Rules: [docs/constitution.md](docs/constitution.md) · agent guide: [AGENTS.md](AGENTS.md).

## License

[MIT](LICENSE)
