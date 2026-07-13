defmodule BetaSigmaWeb.Plugs.RequireRole do
  @moduledoc false

  alias BetaSigmaWeb.UserAuth

  def init(roles) when is_list(roles), do: roles

  def call(conn, roles) do
    conn
    |> UserAuth.require_role(roles)
    |> halt_if_halted()
  end

  defp halt_if_halted(%Plug.Conn{halted: true} = conn), do: conn
  defp halt_if_halted(conn), do: conn
end
