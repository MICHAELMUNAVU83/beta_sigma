defmodule BetaSigma.Repo do
  use Ecto.Repo,
    otp_app: :beta_sigma,
    adapter: Ecto.Adapters.Postgres
end
