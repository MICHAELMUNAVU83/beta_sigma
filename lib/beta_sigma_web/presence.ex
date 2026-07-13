defmodule BetaSigmaWeb.Presence do
  @moduledoc false

  use Phoenix.Presence,
    otp_app: :beta_sigma,
    pubsub_server: BetaSigma.PubSub
end
