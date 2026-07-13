defmodule BetaSigma.Pages do
  @moduledoc """
  Source of truth for every protected page/section in the app.

  Adding a page here once makes it available in:

    * the admin user permissions form (as a checkbox),
    * the sidebar (for users granted access),
    * and the `{:ensure_page, key}` route-level access hook.

  A page is defined by a `:key` (atom), a human `:label`, the `:path`,
  a `:section` used to group pages in the UI, and `:default_roles` — the
  roles that automatically receive access when a user is created.
  """

  alias BetaSigmaWeb.{
    AdminUsersLive,
    ChatLive,
    NotesLive,
    ProjectsLive,
    SprintsLive,
    WorkspaceLive
  }

  @pages [
    %{
      key: :projects,
      label: "Projects",
      path: "/app/projects",
      section: :workspace,
      badge: "Delivery",
      default_roles: [:admin, :staff]
    },
    %{
      key: :sprints,
      label: "Sprints",
      path: "/app/sprints",
      section: :workspace,
      badge: "Delivery",
      default_roles: [:admin, :staff]
    },
    %{
      key: :notes,
      label: "Notes",
      path: "/app/notes",
      section: :workspace,
      badge: "Docs",
      default_roles: [:admin, :staff]
    },
    %{
      key: :notifications,
      label: "Notifications",
      path: "/app/notifications",
      section: :workspace,
      badge: "Live",
      default_roles: [:admin, :staff]
    },
    %{
      key: :chat,
      label: "Chat",
      path: "/app/chat",
      section: :workspace,
      badge: "Live",
      default_roles: [:admin, :staff]
    },
    %{
      key: :users,
      label: "Users",
      path: "/admin/users",
      section: :admin,
      badge: "Admin",
      default_roles: [:admin]
    }
  ]

  @sections [
    %{id: :workspace, label: "Workspace", description: "Day-to-day internal tools."},
    %{id: :admin, label: "Admin", description: "User management."}
  ]

  @view_map %{
    {ProjectsLive.Index, :index} => :projects,
    {ProjectsLive.Show, :show} => :projects,
    {SprintsLive.Index, :index} => :sprints,
    {SprintsLive.Show, :show} => :sprints,
    {NotesLive.Index, :index} => :notes,
    {WorkspaceLive, :notifications} => :notifications,
    {ChatLive.Index, :index} => :chat,
    {AdminUsersLive.Index, :index} => :users
  }

  @doc "Returns every registered page."
  def all, do: @pages

  @doc "Returns every page key as an atom."
  def keys, do: Enum.map(@pages, & &1.key)

  @doc "Returns every page key as a string (for storage in the permissions array)."
  def string_keys, do: Enum.map(@pages, fn %{key: key} -> Atom.to_string(key) end)

  @doc "Looks up a page by key (accepts atoms or strings)."
  def get(key) when is_atom(key), do: Enum.find(@pages, &(&1.key == key))

  def get(key) when is_binary(key) do
    case safe_to_atom(key) do
      nil -> nil
      atom -> get(atom)
    end
  end

  @doc "Returns all page sections in display order."
  def sections, do: @sections

  @doc "Returns the pages belonging to a given section id."
  def pages_in_section(section_id) when is_atom(section_id) do
    Enum.filter(@pages, &(&1.section == section_id))
  end

  @doc """
  Returns the list of page keys (as strings) that should be granted by default
  for the given role. Used to pre-populate a new user's permissions.
  """
  def default_keys_for_role(role) when is_atom(role) do
    @pages
    |> Enum.filter(&(role in &1.default_roles))
    |> Enum.map(fn %{key: key} -> Atom.to_string(key) end)
  end

  @doc """
  Resolves the page key for a LiveView module and live action, or `nil`
  if the view is not a registered protected page.
  """
  def key_for_view(view, live_action) do
    Map.get(@view_map, {view, live_action})
  end

  @doc "Returns true when the given key (atom or string) is a registered page."
  def valid_key?(key) when is_atom(key), do: key in keys()
  def valid_key?(key) when is_binary(key), do: key in string_keys()
  def valid_key?(_), do: false

  @doc """
  Filters a list of permission keys (as stored on the user) down to those
  that still exist in the registry. Lets us drop stale keys for pages
  that were removed.
  """
  def sanitize_keys(keys) when is_list(keys) do
    valid = string_keys()
    keys |> Enum.map(&to_string/1) |> Enum.filter(&(&1 in valid)) |> Enum.uniq()
  end

  def sanitize_keys(_), do: []

  defp safe_to_atom(string) do
    String.to_existing_atom(string)
  rescue
    ArgumentError -> nil
  end
end
