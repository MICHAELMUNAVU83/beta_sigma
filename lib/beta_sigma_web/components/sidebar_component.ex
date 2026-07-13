# credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
# credo:disable-for-this-file Credo.Check.Refactor.Nesting
defmodule BetaSigmaWeb.SidebarComponent do
  @moduledoc false

  use Phoenix.Component
  use Gettext, backend: BetaSigmaWeb.Gettext

  use BetaSigmaWeb, :verified_routes
  import BetaSigmaWeb.CoreComponents
  alias Phoenix.LiveView.JS
  alias BetaSigma.Accounts.User
  alias BetaSigma.Pages

  alias BetaSigmaWeb.UserSettingsLive

  attr :current_user, :map, required: true
  attr :unread_count, :integer, default: 0
  attr :chat_unread_count, :integer, default: 0
  attr :current_view, :any, default: nil
  attr :live_action, :atom, default: nil

  def app_sidebar(assigns) do
    assigns =
      assigns
      |> assign(
        :workspace_links,
        workspace_links(assigns.current_user, assigns.unread_count, assigns.chat_unread_count)
      )
      |> assign(:management_sections, management_sections(assigns.current_user))
      |> assign(:account_links, account_links(assigns.current_user))
      |> assign(:current_view, assigns.current_view)
      |> assign(:live_action, assigns.live_action)

    ~H"""
    <div
      id="app-sidebar-overlay"
      phx-click={close_mobile_sidebar()}
      class="pointer-events-none fixed inset-0 z-40 bg-black/20 opacity-0 transition-opacity duration-200 lg:hidden"
      aria-hidden="true"
    />

    <aside
      id="app-sidebar"
      class="fixed inset-y-0 left-0 z-50 flex h-screen w-[min(18rem,calc(100vw-1.5rem))] -translate-x-full border-r border-neutral-200 bg-white text-neutral-900 shadow-md transition-transform duration-300 lg:z-30 lg:w-72 lg:translate-x-0 lg:shadow-none lg:overflow-hidden"
    >
      <div class="flex h-full flex-col">
        <%!-- Toggle button row --%>
        <div class="flex items-center justify-between border-b border-neutral-200 px-3 py-3">
          <img
            id="sidebar-logo"
            src={~p"/images/logo.png"}
            alt="Vumbuzi Logo"
            class="sidebar-logo mr-auto h-10 w-auto"
          />
          <button
            phx-click={close_mobile_sidebar()}
            class="rounded-md p-2 text-neutral-500 transition hover:bg-neutral-100 hover:text-neutral-900 lg:hidden"
            aria-label="Close sidebar"
          >
            <svg
              class="h-5 w-5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
          <button
            phx-click={
              JS.toggle_class("lg:!w-14", to: "#app-sidebar")
              |> JS.toggle_class("lg:pl-14", to: "#app-main-shell")
              |> JS.toggle_class("lg:pl-72", to: "#app-main-shell")
              |> JS.toggle_class("lg:max-w-none", to: "#app-workspace-shell")
              |> JS.toggle(to: "#sidebar-content")
              |> JS.toggle(to: "#sidebar-logo")
              |> JS.toggle_class("rotate-180", to: "#sidebar-chevron")
            }
            class="hidden rounded-md p-1.5 text-neutral-500 transition hover:bg-neutral-100 hover:text-neutral-900 lg:inline-flex"
            aria-label="Toggle sidebar"
          >
            <svg
              id="sidebar-chevron"
              class="h-5 w-5 transition-transform duration-200"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M11 19l-7-7 7-7m8 14l-7-7 7-7" />
            </svg>
          </button>
        </div>

        <%!-- Collapsible content --%>
        <div id="sidebar-content" class="flex flex-1 flex-col overflow-hidden">
          <div class="border-b border-neutral-200 px-4 py-4">
            <p class="text-xs font-medium text-neutral-400">
              BetaSigma
            </p>
          </div>

          <nav class="flex-1 space-y-6 overflow-y-auto px-3 py-4">
            <.nav_section
              :if={@workspace_links != []}
              title="Workspace"
              links={@workspace_links}
              current_view={@current_view}
              live_action={@live_action}
            />
            <.nav_group
              :if={@management_sections != []}
              title="Admin & HR"
              sections={@management_sections}
              current_view={@current_view}
              live_action={@live_action}
            />
            <.nav_section
              title="Account"
              links={@account_links}
              current_view={@current_view}
              live_action={@live_action}
            />
          </nav>

          <div class="border-t border-neutral-200 p-3 mt-auto shrink-0">
            <div class="flex items-center gap-3 rounded-md p-2 transition hover:bg-neutral-100">
              <.avatar user={@current_user} class="h-9 w-9 text-sm" />
              <div class="flex-1 min-w-0">
                <p class="truncate text-sm font-medium text-neutral-900">
                  {display_name(@current_user)}
                </p>
                <p class="truncate text-xs text-neutral-500">{@current_user.email}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </aside>
    """
  end

  attr :title, :string, required: true
  attr :links, :list, required: true
  attr :current_view, :any, default: nil
  attr :live_action, :atom, default: nil

  defp nav_section(assigns) do
    ~H"""
    <section>
      <p class="px-2 text-xs font-medium text-neutral-400">{@title}</p>
      <div class="mt-2 space-y-0.5">
        <.link
          :for={link <- @links}
          href={link.path}
          phx-click={close_mobile_sidebar()}
          class={nav_link_class(active_link?(link, @current_view, @live_action))}
        >
          <span>{link.label}</span>
        </.link>
      </div>
    </section>
    """
  end

  attr :title, :string, required: true
  attr :sections, :list, required: true
  attr :current_view, :any, default: nil
  attr :live_action, :atom, default: nil

  defp nav_group(assigns) do
    ~H"""
    <section>
      <p class="px-2 text-xs font-medium text-neutral-400">{@title}</p>
      <div class="mt-2 space-y-4">
        <section :for={section <- @sections}>
          <div class="px-2">
            <p class="text-xs font-medium text-neutral-400">
              {section.title}
            </p>
          </div>

          <div class="mt-1 space-y-0.5">
            <.link
              :for={link <- section.links}
              href={link.path}
              phx-click={close_mobile_sidebar()}
              class={nav_link_class(active_link?(link, @current_view, @live_action))}
            >
              <span>{link.label}</span>
            </.link>
          </div>
        </section>
      </div>
    </section>
    """
  end

  def workspace_home(%User{}), do: ~p"/app/projects"
  def workspace_home(_), do: ~p"/"

  def display_name(nil), do: "Unknown"

  def display_name(%Ecto.Association.NotLoaded{}), do: "Unknown"

  def display_name(%User{name: name, email: email}) do
    case String.trim(name || "") do
      "" -> email
      trimmed -> trimmed
    end
  end

  defp workspace_links(%User{} = user, unread_count, chat_unread_count) do
    :workspace
    |> Pages.pages_in_section()
    |> Enum.filter(&User.can_access?(user, &1.key))
    |> Enum.map(&to_link(&1, unread_count, chat_unread_count))
  end

  defp workspace_links(_, _, _), do: []

  defp management_sections(%User{} = user) do
    accessible_pages =
      Pages.pages_in_section(:admin)
      |> Enum.filter(&User.can_access?(user, &1.key))
      |> Map.new(fn page -> {page.key, to_link(page, 0, 0)} end)

    [
      %{
        title: "People",
        description: "User access.",
        keys: [:users]
      }
    ]
    |> Enum.map(fn section ->
      links =
        Enum.flat_map(section.keys, fn key ->
          case Map.fetch(accessible_pages, key) do
            {:ok, link} -> [link]
            :error -> []
          end
        end)

      Map.put(section, :links, links)
    end)
    |> Enum.filter(&(&1.links != []))
  end

  defp management_sections(_), do: []

  defp to_link(%{key: :notifications} = page, unread_count, _chat_unread_count) do
    %{label: page.label, path: page.path, badge: notification_badge(unread_count), key: page.key}
  end

  defp to_link(%{key: :chat} = page, _unread_count, chat_unread_count) do
    %{label: page.label, path: page.path, badge: chat_badge(chat_unread_count), key: page.key}
  end

  defp to_link(page, _unread_count, _chat_unread_count) do
    %{label: page.label, path: page.path, badge: page.badge, key: page.key}
  end

  defp account_links(_user) do
    [
      %{label: "Back to Home", path: ~p"/", badge: "Home", key: :home},
      %{
        label: "Account Settings",
        path: ~p"/users/settings",
        badge: "Auth",
        key: :account_settings
      }
    ]
  end

  defp active_link?(%{key: :account_settings}, UserSettingsLive, _live_action), do: true

  defp active_link?(%{key: key}, current_view, live_action) do
    Pages.key_for_view(current_view, live_action) == key
  end

  defp active_link?(_link, _current_view, _live_action), do: false

  defp nav_link_class(true),
    do:
      "flex items-center justify-between rounded-md bg-neutral-100 px-2 py-1.5 text-sm font-medium text-neutral-900 transition"

  defp nav_link_class(false),
    do:
      "flex items-center justify-between rounded-md px-2 py-1.5 text-sm text-neutral-600 transition hover:bg-neutral-100 hover:text-neutral-900"

  defp notification_badge(unread_count) when is_integer(unread_count) and unread_count > 0,
    do: Integer.to_string(unread_count)

  defp notification_badge(_unread_count), do: "Live"

  defp chat_badge(count) when is_integer(count) and count > 0,
    do: Integer.to_string(min(count, 99))

  defp chat_badge(_count), do: "Chat"

  def sidebar_role_copy(:admin), do: "Full access to internal and admin routes."
  def sidebar_role_copy(:staff), do: "Internal workspace access without admin-only modules."
  def sidebar_role_copy(_role), do: "Signed-in workspace access."

  def open_mobile_sidebar(js \\ %JS{}) do
    js
    |> JS.remove_class("-translate-x-full", to: "#app-sidebar")
    |> JS.remove_class("opacity-0", to: "#app-sidebar-overlay")
    |> JS.remove_class("pointer-events-none", to: "#app-sidebar-overlay")
    |> JS.add_class("overflow-hidden", to: "body")
  end

  def close_mobile_sidebar(js \\ %JS{}) do
    js
    |> JS.add_class("-translate-x-full", to: "#app-sidebar")
    |> JS.add_class("opacity-0", to: "#app-sidebar-overlay")
    |> JS.add_class("pointer-events-none", to: "#app-sidebar-overlay")
    |> JS.remove_class("overflow-hidden", to: "body")
  end
end
