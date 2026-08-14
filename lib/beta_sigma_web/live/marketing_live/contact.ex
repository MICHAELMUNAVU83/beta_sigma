defmodule BetaSigmaWeb.MarketingLive.Contact do
  use BetaSigmaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Partner With Us - BeCorp")
     |> assign(
       :meta_description,
       "BeCorp is a diversified investment and operating company that builds, scales and manages high-growth industries across strategic sectors in Africa."
     )
     |> assign(:active_nav, :contact)
     |> assign(:contact_form, blank_form())}
  end

  @impl true
  def handle_event("submit_contact", %{"contact" => params}, socket) do
    {:noreply,
     socket
     |> assign(:contact_form, blank_form())
     |> put_flash(
       :info,
       "Thanks #{params["name"]}! We've received your message and will be in touch shortly."
     )}
  end

  defp blank_form do
    to_form(%{"name" => "", "email" => "", "company" => "", "message" => ""}, as: "contact")
  end
end
