defmodule BetaSigmaWeb.MarketingLive.About do
  use BetaSigmaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Who We Are - BeCorp")
     |> assign(
       :meta_description,
       "BeCorp is a diversified investment and operating company that builds, scales and manages high-growth industries across strategic sectors in Africa."
     )
     |> assign(:active_nav, :about)}
  end
end
