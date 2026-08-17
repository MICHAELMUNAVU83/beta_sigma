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
      |> assign(
        :conversation_links,
        conversation_links(assigns.current_user, assigns.chat_unread_count)
      )
      |> assign(:management_sections, management_sections(assigns.current_user))
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
      class="fixed inset-y-0 left-0 z-50 flex h-screen w-[min(18rem,calc(100vw-1.5rem))] -translate-x-full border-r border-white/10 bg-ink text-n100 transition-transform duration-300 lg:z-30 lg:w-72 lg:translate-x-0 lg:overflow-hidden"
    >
      <div class="flex h-full w-full flex-col">
        <%!-- Toggle button row --%>
        <div class="flex h-[53px] items-center justify-between border-b border-white/10 px-5">
          <.link navigate={~p"/"} id="sidebar-logo" class="flex items-center gap-2">
            <img
              src={~p"/images/becorp-logo.png"}
              alt="BΣ Corporation"
              class="h-7 w-auto"
              decoding="async"
            />
          </.link>
          <button
            phx-click={close_mobile_sidebar()}
            class="p-2 text-n600 transition hover:text-accent lg:hidden"
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
            class="hidden p-1.5 text-n600 transition hover:text-accent lg:inline-flex"
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
          <nav class="flex-1 space-y-5 overflow-y-auto px-4 pb-5 pt-1">
            <.nav_section
              :if={@workspace_links != []}
              title=""
              links={@workspace_links}
              current_view={@current_view}
              live_action={@live_action}
            />
            <.nav_section
              :if={@conversation_links != []}
              title="Conversations"
              links={@conversation_links}
              current_view={@current_view}
              live_action={@live_action}
            />
            <.nav_group
              :if={@management_sections != []}
              title="Admin"
              sections={@management_sections}
              current_view={@current_view}
              live_action={@live_action}
            />
          </nav>

          <div class="mt-auto shrink-0 border-t border-white/10 px-5 py-5">
            <.link
              navigate={~p"/users/settings"}
              class="flex min-w-0 items-center gap-3 py-2 transition hover:text-accent"
            >
              <.avatar user={@current_user} class="h-10 w-10 text-sm" />
              <div class="flex-1 min-w-0">
                <p class="truncate text-base font-bold text-n100">
                  {display_name(@current_user)}
                </p>
                <p class="truncate text-sm font-semibold text-n600">
                  {@current_user.email}
                </p>
              </div>
            </.link>

            <.form action={~p"/users/log_out"} method="delete" class="mt-6">
              <button
                type="submit"
                class="flex w-full items-center gap-4 py-2 text-lg font-bold text-n600 transition hover:text-accent"
              >
                <.icon name="hero-arrow-right-on-rectangle" class="h-6 w-6 text-n600" />
                <span>Sign out.</span>
              </button>
            </.form>
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
      <p
        :if={@title != ""}
        class="px-3 text-sm uppercase tracking-[0.1em] text-n600"
      >
        {@title}
      </p>
      <div class={["space-y-2", @title != "" && "mt-3"]}>
        <.nav_item
          :for={link <- @links}
          link={link}
          active={active_link?(link, @current_view, @live_action)}
        />
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
      <p class="px-3 text-sm uppercase tracking-[0.1em] text-n600">
        {@title}
      </p>
      <div class="mt-3 space-y-4">
        <section :for={section <- @sections}>
          <div :if={section.title != ""} class="px-3">
            <p class="text-xs uppercase tracking-[0.1em] text-n600/70">
              {section.title}
            </p>
          </div>

          <div class={["space-y-2", section.title != "" && "mt-2"]}>
            <.nav_item
              :for={link <- section.links}
              link={link}
              active={active_link?(link, @current_view, @live_action)}
            />
          </div>
        </section>
      </div>
    </section>
    """
  end

  attr :link, :map, required: true
  attr :active, :boolean, required: true

  defp nav_item(assigns) do
    ~H"""
    <.link href={@link.path} phx-click={close_mobile_sidebar()} class={nav_link_class(@active)}>
      <span class="flex min-w-0 items-center gap-4">
        <.icon name={@link.icon} class={nav_icon_class(@active)} />
        <span class="truncate">{@link.label}</span>
      </span>
      <span :if={@link.badge} class={nav_badge_class(@active)}>
        {@link.badge}
      </span>
    </.link>
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
    |> Enum.reject(&(&1.key == :chat))
    |> Enum.filter(&User.can_access?(user, &1.key))
    |> Enum.map(&to_link(&1, unread_count, chat_unread_count))
  end

  defp workspace_links(_, _, _), do: []

  defp conversation_links(%User{} = user, chat_unread_count) do
    :workspace
    |> Pages.pages_in_section()
    |> Enum.filter(&(&1.key == :chat))
    |> Enum.filter(&User.can_access?(user, &1.key))
    |> Enum.map(&to_link(&1, 0, chat_unread_count))
  end

  defp conversation_links(_, _), do: []

  defp management_sections(%User{} = user) do
    accessible_pages =
      Pages.pages_in_section(:admin)
      |> Enum.filter(&User.can_access?(user, &1.key))
      |> Map.new(fn page -> {page.key, to_link(page, 0, 0)} end)

    [
      %{
        title: "",
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
    page
    |> base_link()
    |> Map.put(:badge, count_badge(unread_count))
  end

  defp to_link(%{key: :chat} = page, _unread_count, chat_unread_count) do
    page
    |> base_link()
    |> Map.put(:badge, count_badge(chat_unread_count))
  end

  defp to_link(page, _unread_count, _chat_unread_count) do
    base_link(page)
  end

  defp base_link(page),
    do: %{label: page.label, path: page.path, badge: nil, key: page.key, icon: nav_icon(page.key)}

  defp active_link?(%{key: key}, current_view, live_action) do
    Pages.key_for_view(current_view, live_action) == key
  end

  defp active_link?(_link, _current_view, _live_action), do: false

  defp nav_link_class(true),
    do:
      "flex min-h-14 items-center justify-between gap-3 px-5 py-3 text-lg font-semibold text-accent transition hover:bg-white/5"

  defp nav_link_class(false),
    do:
      "flex min-h-14 items-center justify-between gap-3 px-5 py-3 text-lg font-medium text-n500 transition hover:bg-white/5 hover:text-n100"

  defp nav_icon_class(true), do: "h-6 w-6 shrink-0 text-accent"
  defp nav_icon_class(false), do: "h-6 w-6 shrink-0 text-n600"

  defp nav_badge_class(true),
    do:
      "ml-3 inline-flex h-8 min-w-8 shrink-0 items-center justify-center bg-accent px-2 text-base font-semibold text-n100"

  defp nav_badge_class(false),
    do:
      "ml-3 inline-flex h-7 min-w-7 shrink-0 items-center justify-center bg-accent px-2 text-sm font-semibold text-n100"

  defp count_badge(count) when is_integer(count) and count > 0 do
    if count > 99, do: "99+", else: Integer.to_string(count)
  end

  defp count_badge(_count), do: nil

  defp nav_icon(:projects), do: "hero-eye"
  defp nav_icon(:sprints), do: "hero-clipboard-document-check"
  defp nav_icon(:notes), do: "hero-document-text"
  defp nav_icon(:notifications), do: "hero-bell"
  defp nav_icon(:chat), do: "hero-chat-bubble-left-right"
  defp nav_icon(:discovery), do: "hero-magnifying-glass-circle"
  defp nav_icon(:users), do: "hero-user-group"
  defp nav_icon(_key), do: "hero-squares-2x2"

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
