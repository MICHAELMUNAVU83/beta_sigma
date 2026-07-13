defmodule BetaSigmaWeb.ConnCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint BetaSigmaWeb.Endpoint

      use BetaSigmaWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import BetaSigmaWeb.ConnCase
    end
  end

  setup tags do
    BetaSigma.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  def log_in_user(conn, user) do
    token = BetaSigma.Accounts.generate_user_session_token(user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end
end
