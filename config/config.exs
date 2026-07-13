# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :beta_sigma,
  ecto_repos: [BetaSigma.Repo],
  generators: [timestamp_type: :utc_datetime],
  chat_side_effects: :async

config :beta_sigma, :uploads,
  directory: Path.expand("../uploads", __DIR__),
  base_url_path: "/uploads"

config :beta_sigma, Oban,
  repo: BetaSigma.Repo,
  queues: [default: 10, mailers: 5],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    {Oban.Plugins.Cron,
     crontab: [
       {"30 8 * * *", BetaSigma.Workers.TaskReminderWorker}
     ]}
  ]

# Configures the endpoint
config :beta_sigma, BetaSigmaWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: BetaSigmaWeb.ErrorHTML, json: BetaSigmaWeb.ErrorJSON],
    layout: [html: {BetaSigmaWeb.Layouts, :root}, json: false]
  ],
  pubsub_server: BetaSigma.PubSub,
  live_view: [signing_salt: "roewAfpp"]

# Configures outbound email delivery.
config :beta_sigma, BetaSigma.Mailer, delivery_mode: :resend

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  beta_sigma: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  beta_sigma: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
