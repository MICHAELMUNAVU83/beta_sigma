# BetaSigma

BetaSigma is a Phoenix LiveView application for BetaSigma's internal operations. It combines chat, project delivery, sprints, notes, and notifications.

Major areas:

- Internal workspace: chat, projects, sprints, notes, and notifications.
- Accounts: authentication and admin user management.

## Prerequisites

- Elixir `~> 1.14` from `mix.exs`; there is no `.tool-versions` file in this repo.
- Erlang/OTP compatible with the installed Elixir/Phoenix version; not pinned in the repo.
- PostgreSQL running locally as `postgres` / `postgres`.
- Node/npm for `assets/package.json` dependencies; no Node version is pinned.

## Setup

```sh
mix setup
```

The `setup` alias runs dependency install, database create/migrate/seed, and asset setup/build. Development database defaults to `beta_sigma_dev` on `localhost`.

## Run

```sh
mix phx.server
```

Open [http://localhost:4210](http://localhost:4210).

## Seeded Logins

| Role  | Email                       | Password       |
| ----- | --------------------------- | -------------- |
| Admin | `michaelmunavu83@gmail.com` | `123456`       |
| Staff | `staff@vumbuzi-ai.co.ke`    | `password1234` |

## Common Commands

```sh
./scripts/check_linters.sh
mix test
mix format
mix format --check-formatted
mix credo
mix run priv/repo/seeds.exs
mix assets.build
mix assets.deploy
```

Run `./scripts/check_linters.sh` before opening a pull request. It checks formatting, runs Credo in strict mode, and runs the test suite.

`mix ecto.setup` runs `ecto.create`, `ecto.migrate`, and seeds. `mix ecto.drop` and `mix ecto.reset` are intentionally blocked in `mix.exs` to prevent accidental destructive database operations.

## Opening a Pull Request

Before opening a pull request:

1. Run `./scripts/check_linters.sh` and fix any formatting, Credo, or test failures.
2. Fill out the pull request summary, changes, and how-to-test sections.
3. Add screenshots or screen recordings for UI changes. Use `N/A` when there are no visual changes.
4. Complete the pull request checklist, including docs, migrations, seeds, and secrets checks when relevant.

### Commit Messages

Use the format `name/what-pr-does` for commit messages.

Examples:

```sh
michael/add-lab-order-filters
sarah/fix-prescription-validation
```

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Domains](docs/DOMAINS.md)
- [Portals](docs/PORTALS.md)
- [Authentication and Authorization](docs/AUTH.md)
- [Data Model](docs/DATA_MODEL.md)
- [Workflows](docs/WORKFLOWS.md)
- [Environment](docs/ENVIRONMENT.md)
