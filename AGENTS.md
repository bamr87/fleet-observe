<!-- kit: sdlc v0.2.0 · AGENTS.md is the CANONICAL agent instructions file (decision D4, UPS-AGENT-07/08).
     Keep these six `##` headings (UPS-AGENT-07 checks they exist, in any order; add your own headings as needed). CLAUDE.md is a pointer to this file and carries no rules of its own. -->

# fleet-observe

> fleet-observe's direction is to become the ultimate open home for all things fleet observability: data, tools, resources and transparency, with OpenTelemetry, Prometheus and Grafana wired for every fleet service, for everyone ([constitution](docs/constitution.md) §1).

## What this repo is

Observability stack for the bamr87 fleet: OpenTelemetry Collector, Prometheus and Grafana, wired for every fleet service. Metrics, traces and dashboards for the whole fleet from one compose file, ready to move onto the fleet-infra cluster.

**Read [docs/constitution.md](docs/constitution.md) first.** "Done" for a change means: CI green, the feature catalog entry and PRD block updated in the same PR, and a human merged it.

## Stack & commands

```bash
cp .env.example .env                                   # set GRAFANA_ADMIN_PASSWORD
GRAFANA_ADMIN_PASSWORD=x docker compose config -q      # compose syntax (CI's first step)
python3 scripts/check_compose.py                       # ports loopback-only, password required
shellcheck scripts/*.sh                                # lint the scripts
scripts/validate.sh                                    # compose, otel/config.yaml and prometheus.yml, in the pinned images
scripts/smoke.sh                                       # starts healthy, an OTLP metric reaches Prometheus (own project, removed after)
docker compose up -d --wait                            # run the stack; `down` keeps data, `down -v` deletes it
```

Image tags live only in `compose.yml`; the scripts read them from there, so never repeat a tag elsewhere.

Every published port is `"127.0.0.1:${NAME_PORT:-<default>}:<container>"` (hub UPS-REPO-34); never add a bare `N:N` mapping. A new port also gets its variable in `.env.example` and a row in the README table.

`scripts/smoke.sh` runs as compose project `fobs-smoke` and removes it with `down -v` when it ends (unless `--keep` or `--no-up`), so never point `SMOKE_PROJECT` at a stack whose data you want to keep. When the default ports are taken (on a machine that also runs the hub's observability plane, it holds 4317, 4318 and 9090), export free ones first, for example `OTEL_GRPC_PORT=14317 OTEL_HTTP_PORT=14318 PROMETHEUS_PORT=19090 GRAFANA_PORT=13000 OTEL_HEALTH_PORT=23133`.

## Layout

- `docs/` — constitution, amendments, ADRs
- `features/features.yml` — the feature catalog (prefix `FOBS-`)
- `PRD.md` — requirements (FRn/NFRn) and the phased roadmap
- `.github/` — CI, the `@claude` handler, the `evolve` lane (off by default), issue forms
- `.claude/agents/builder.md` — the role the evolve lane runs as
- `scripts/check_compose.py` — CI guard for compose.yml's port binding and Grafana credential
- `scripts/validate.sh` — validates compose.yml, the collector config and the Prometheus config with the pinned images (CI runs it)
- `scripts/smoke.sh` — starts the stack in its own project, waits for it to be healthy and proves an OTLP metric reaches Prometheus (CI runs it)
- `.env.example` — every compose variable, no real values (copy to the git-ignored `.env`)
- everything else — the opentelemetry, prometheus skeleton

## Conventions

- **Backlog of record:** GitHub Issues with the fleet labels. Pick up issues labelled `agent:ready`; never touch `agent:hold` or `human-review`. <!-- File-backlog repos: "BACKLOG.md (append-only, BL-YYYYMMDD-NN), declared in .github/sdlc.yml" -->
- **Definition of Done:** the checklist in `.github/pull_request_template.md` (the fleet default is inherited when the repo has none). Every box is ticked before merge.
- **Decisions:** ADRs in `docs/adr/NNNN-slug.md`, indexed in `docs/adr/README.md`. Add one for anything hard to reverse.
- **Commits:** Conventional Commits (`feat fix docs style refactor test chore perf ci build`). The PR title is the squash subject.
- **Branches:** `feature/`, `fix/`, `docs/`, `refactor/`, `test/` or `chore/` off `main`.
- **Changelog:** `CHANGELOG.md` is written by release-please from the PR titles. Never edit it, or a version number, by hand.
- **Never:** push to `main` directly, commit lockfiles or secrets, suppress type errors, leave empty exception handlers, or edit generated files by hand.

## Fleet context

Continuous evolution: the hub's weekly repo-evolution loop and backlog fan-out open PRs here (never merge); the local `evolve` lane builds the next `status: planned` feature only when the `EVOLVE_ENABLED` repo variable is `true`.

Member of the bamr87 fleet. The standards live in the hub: <https://github.com/bamr87/bamr87/tree/main/specs> (the Universal Project Standard). The repo's SDLC declaration is `.github/sdlc.yml`. Commit here first; the hub bumps its submodule pointer afterwards.

## Standard deviations

none
<!-- Or one line per waived row, matching .github/sdlc.yml `deviations:`:
- UPS-WORK-07 waived until 2027-01-01: reason -->
