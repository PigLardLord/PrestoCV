# For coding agents

An agent working on PrestoCV follows the same rules as a person. This file says where they are; read them before a change.

- **How to build, test, commit and open a pull request:** [CONTRIBUTING.md](CONTRIBUTING.md). Files, commits, pull requests and issues name no coding assistant and no model, and commits carry no attribution trailer for them.
- **The architecture:** [docs/architecture/README.md](docs/architecture/README.md), then [rules.md](docs/architecture/rules.md) (R1–R19) and [modules.md](docs/architecture/modules.md) (each target and the imports it may use). New code follows the target architecture, not the legacy code around it. Where another document disagrees with `docs/architecture/`, `docs/architecture/` wins.
- **The decisions:** the ADRs in [docs/architecture/adr/](docs/architecture/adr/README.md). An ADR binds once it is Accepted and merged; a Proposed one guides new code.
- **Where things are:** the table in the [README](README.md#where-things-are).
- **Reviews:** [docs/maintainers/reviews.md](docs/maintainers/reviews.md).
