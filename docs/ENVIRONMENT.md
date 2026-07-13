# Environment

## Development

Development config lives in `config/dev.exs`.

| Setting | Value |
| --- | --- |
| Database username | `postgres` |
| Database password | `postgres` |
| Database host | `localhost` |
| Database name | `beta_sigma_dev` |
| HTTP port | `4210` |
| Dev routes | enabled |
| Live reload | enabled |

Optional development env vars:

| Variable | Purpose |
| --- | --- |
| `PHX_DEBUG_ERRORS` | Enables Phoenix debug error pages when `true` or `1`. |
| `OPENAI_API_KEY` | Used by `BetaSigma.OpenAI` when config does not provide a key. |
| `RESEND_API_KEY` | Required for real Resend email delivery. |
| `MAILER_DELIVERY_MODE` | `gmail` logs a deprecation warning and still uses Resend; other values use configured defaults. |

The default upload directory is `uploads/`.

## Test

Test config lives in `config/test.exs`.

- Database name is `beta_sigma_test#{System.get_env("MIX_TEST_PARTITION")}`.
- Endpoint server is disabled.
- Mailer delivery mode is `:noop`.
- Oban uses manual testing mode.

## Production

Production runtime config lives in `config/runtime.exs`.

Required:

| Variable | Purpose |
| --- | --- |
| `DATABASE_URL` | Ecto database URL, for example `ecto://USER:PASS@HOST/DATABASE`. |
| `SECRET_KEY_BASE` | Phoenix cookie/session signing secret. Generate with `mix phx.gen.secret`. |

Optional:

| Variable | Purpose | Default |
| --- | --- | --- |
| `PHX_SERVER` | Starts the endpoint in releases when present. | unset |
| `ECTO_IPV6` | Enables IPv6 socket options when `true` or `1`. | unset |
| `POOL_SIZE` | Database connection pool size. | `10` |
| `PHX_HOST` | Public host for endpoint URLs. | `example.com` |
| `PORT` | HTTP port. | `4000` |
| `DNS_CLUSTER_QUERY` | DNSCluster discovery query. | unset |
| `UPLOADS_DIR` | Upload storage directory. | `uploads` under release root/current dir |
| `OPENAI_API_KEY` | Fallback OpenAI API key. | unset |
| `RESEND_API_KEY` | Resend API key for email delivery. | unset |
| `RESEND_FROM_EMAIL` | Verified sender address for Resend. | configured sender |
| `RESEND_FROM_NAME` | Sender display name for Resend. | configured sender |

TODO: `runtime.exs` also contains a hard-coded OpenAI API key value in application config. Rotate that key if real, remove it from source, and rely on `OPENAI_API_KEY` or a secrets manager.

## Application Config

Static config in `config/config.exs` includes:

- `:uploads` directory and URL path.
- Oban queues: `default`, `mailers`.
- Oban cron workers: task reminders.
- `BetaSigma.Mailer` delivery mode default: `:resend`.
- esbuild and Tailwind versions/config.

Additional runtime reads in code:

- `:beta_sigma, :openai_client` can override the OpenAI module in tests or integrations.
- `BetaSigma.Mailer` reads app config for provider behavior.

## Mix Aliases

Defined in `mix.exs`:

| Alias | Runs |
| --- | --- |
| `mix setup` | `deps.get`, `ecto.setup`, `assets.setup`, `assets.build` |
| `mix ecto.setup` | `ecto.create`, `ecto.migrate`, `run priv/repo/seeds.exs` |
| `mix test` | quiet create, quiet migrate, tests |
| `mix assets.setup` | Tailwind and esbuild install |
| `mix assets.build` | Tailwind and esbuild build |
| `mix assets.deploy` | minified Tailwind/esbuild and `phx.digest` |

`mix ecto.drop` and `mix ecto.reset` are intentionally overridden to raise `Database drop/reset tasks are disabled for this project.`
