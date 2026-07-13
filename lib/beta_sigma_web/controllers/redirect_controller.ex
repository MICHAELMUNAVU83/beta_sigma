defmodule BetaSigmaWeb.RedirectController do
  use BetaSigmaWeb, :controller

  def login(conn, _params) do
    redirect(conn, to: ~p"/users/log_in")
  end
end
