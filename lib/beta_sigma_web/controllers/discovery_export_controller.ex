defmodule BetaSigmaWeb.DiscoveryExportController do
  use BetaSigmaWeb, :controller

  alias BetaSigma.Discovery

  @doc "Downloads a discovery session as a Markdown handover."
  def show(conn, %{"id" => id}) do
    session = Discovery.get_session!(id)

    filename =
      [session.department.slug, session.held_on || Date.utc_today()]
      |> Enum.join("-")
      |> Kernel.<>(".md")

    conn
    |> put_resp_content_type("text/markdown")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, Discovery.to_markdown(session))
  end
end
