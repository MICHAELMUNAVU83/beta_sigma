import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :beta_sigma, BetaSigma.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "beta_sigma_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :beta_sigma, BetaSigmaWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "FvJmwmiW7pI3X/OzCf4uH3QmTqGEAdX3pppXgr7/eiDkp/0ZMKycps+JNsrCQJXL",
  server: false

# In test we don't send emails
config :beta_sigma, BetaSigma.Mailer, delivery_mode: :noop
config :beta_sigma, :chat_side_effects, :sync

config :beta_sigma, Oban, testing: :manual

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
