defmodule BetaSigma.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    BetaSigma.Uploads.ensure_directories!()

    children =
      [
        BetaSigmaWeb.Telemetry,
        BetaSigma.Repo,
        {DNSCluster, query: Application.get_env(:beta_sigma, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: BetaSigma.PubSub},
        BetaSigmaWeb.Presence,
        {Task.Supervisor, name: BetaSigma.TaskSupervisor},
        {Oban, Application.fetch_env!(:beta_sigma, Oban)},
        # Start the Finch HTTP client for sending emails
        {Finch, name: BetaSigma.Finch},
        # Start a worker by calling: BetaSigma.Worker.start_link(arg)
        # {BetaSigma.Worker, arg},
        # Start to serve requests, typically the last entry
        BetaSigmaWeb.Endpoint
      ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BetaSigma.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BetaSigmaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
