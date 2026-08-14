defmodule BetaSigmaWeb.MarketingLive.Home do
  use BetaSigmaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "BeCorp - Building industries That Shape Africa's Future")
     |> assign(
       :meta_description,
       "BeCorp is a diversified investment and operating company that builds, scales and manages high-growth industries across strategic sectors in Africa."
     )
     |> assign(:active_nav, :home)}
  end
end
