defmodule BetaSigmaWeb.AdminUsersLive.Index do
  use BetaSigmaWeb, :live_view

  alias BetaSigma.Accounts
  alias BetaSigma.Accounts.User
  alias BetaSigma.Pages
  alias BetaSigmaWeb.Realtime

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> Realtime.bootstrap()
     |> assign(:page_title, "User accounts")
     |> assign(:active_modal, nil)
     |> assign(:role_filter, "all")
     |> assign(:search_query, "")
     |> assign(:new_user_role, "staff")
     |> assign(:new_user_permissions, Pages.default_keys_for_role(:staff))
     |> assign(:editing_role, nil)
     |> assign(:editing_permissions, [])
     |> load_page()
     |> reset_user_form()}
  end

  def handle_event("filter_role", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, :role_filter, filter)}
  end

  def handle_event("search_users", %{"value" => query}, socket) do
    {:noreply, assign(socket, :search_query, String.trim(query))}
  end

  def handle_event("new_user", _params, socket) do
    {:noreply,
     socket
     |> reset_user_form()
     |> assign(:active_modal, :user)}
  end

  def handle_event("close_modal", %{"modal" => "user"}, socket) do
    {:noreply,
     socket
     |> reset_user_form()
     |> assign(:active_modal, nil)}
  end

  def handle_event("close_modal", %{"modal" => "edit_access"}, socket) do
    {:noreply, assign(socket, :active_modal, nil)}
  end

  def handle_event("validate_user", %{"user" => params}, socket) do
    changeset =
      Accounts.change_user_registration(%User{}, params)
      |> Map.put(:action, :validate)

    role = params["role"] || socket.assigns.new_user_role
    permissions = selected_permissions(params, socket.assigns.new_user_permissions)

    {:noreply,
     socket
     |> assign(:user_changeset, changeset)
     |> assign(:new_user_role, role)
     |> assign(:new_user_permissions, permissions)}
  end

  def handle_event("new_user_role_changed", %{"user" => %{"role" => role}}, socket) do
    role_atom = safe_role_atom(role)
    defaults = Pages.default_keys_for_role(role_atom || :staff)

    {:noreply,
     socket
     |> assign(:new_user_role, role)
     |> assign(:new_user_permissions, defaults)}
  end

  def handle_event("save_user", %{"user" => params}, socket) do
    params =
      params
      |> Map.update("name", "", &String.trim/1)
      |> Map.update("email", "", &String.trim/1)
      |> Map.put("password", temporary_password())

    role = params["role"] || "staff"
    role_atom = safe_role_atom(role) || :staff
    permissions = selected_permissions(params, socket.assigns.new_user_permissions)

    case Accounts.register_user(params) do
      {:ok, user} ->
        Accounts.update_user_access(user, %{role: role_atom, permissions: permissions})

        Accounts.deliver_user_reset_password_instructions(
          user,
          &url(~p"/users/reset_password/#{&1}")
        )

        {:noreply,
         socket
         |> put_flash(
           :info,
           "User created. A password reset link has been sent to #{user.email}."
         )
         |> load_page()
         |> reset_user_form()
         |> assign(:active_modal, nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :user_changeset, Map.put(changeset, :action, :validate))}
    end
  end

  def handle_event("edit_access", %{"id" => id}, socket) do
    user = Accounts.get_user!(String.to_integer(id))

    {:noreply,
     socket
     |> assign(:editing_user, user)
     |> assign(:editing_role, Atom.to_string(user.role))
     |> assign(:editing_permissions, user.permissions || [])
     |> assign(:active_modal, :edit_access)}
  end

  def handle_event("edit_role_select", %{"role" => role}, socket) do
    role_atom = safe_role_atom(role)
    current_user = socket.assigns.editing_user

    permissions =
      if current_user && role_atom && role_atom != current_user.role do
        Pages.default_keys_for_role(role_atom)
      else
        socket.assigns.editing_permissions
      end

    {:noreply,
     socket
     |> assign(:editing_role, role)
     |> assign(:editing_permissions, permissions)}
  end

  def handle_event("edit_toggle_permission", %{"key" => key}, socket) do
    permissions = toggle_permission(socket.assigns.editing_permissions, key)
    {:noreply, assign(socket, :editing_permissions, permissions)}
  end

  def handle_event("edit_select_all", %{"section" => section}, socket) do
    section_keys = section_keys(section)
    permissions = Enum.uniq(socket.assigns.editing_permissions ++ section_keys)
    {:noreply, assign(socket, :editing_permissions, permissions)}
  end

  def handle_event("edit_clear_section", %{"section" => section}, socket) do
    section_keys = section_keys(section)
    permissions = Enum.reject(socket.assigns.editing_permissions, &(&1 in section_keys))
    {:noreply, assign(socket, :editing_permissions, permissions)}
  end

  def handle_event("new_toggle_permission", %{"key" => key}, socket) do
    permissions = toggle_permission(socket.assigns.new_user_permissions, key)
    {:noreply, assign(socket, :new_user_permissions, permissions)}
  end

  def handle_event("save_access", _params, socket) do
    user = socket.assigns.editing_user
    role_atom = safe_role_atom(socket.assigns.editing_role) || user.role
    permissions = socket.assigns.editing_permissions

    case Accounts.update_user_access(user, %{role: role_atom, permissions: permissions}) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Access updated for #{user.email}.")
         |> load_page()
         |> assign(:active_modal, nil)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not update access.")}
    end
  end

  def handle_event("send_reset_password", %{"id" => id}, socket) do
    user = Accounts.get_user!(String.to_integer(id))

    Accounts.deliver_user_reset_password_instructions(
      user,
      &url(~p"/users/reset_password/#{&1}")
    )

    {:noreply, put_flash(socket, :info, "Password reset link sent to #{user.email}.")}
  end

  def handle_event("send_confirmation", %{"id" => id}, socket) do
    user = Accounts.get_user!(String.to_integer(id))

    case Accounts.deliver_user_confirmation_instructions(
           user,
           &url(~p"/users/confirm/#{&1}")
         ) do
      {:ok, _} ->
        {:noreply, put_flash(socket, :info, "Confirmation email sent to #{user.email}.")}

      {:error, :already_confirmed} ->
        {:noreply, put_flash(socket, :info, "#{user.email} is already confirmed.")}
    end
  end

  def handle_event("delete_user", %{"id" => id}, socket) do
    user = Accounts.get_user!(String.to_integer(id))

    cond do
      user.id == socket.assigns.current_user.id ->
        {:noreply, put_flash(socket, :error, "You cannot delete your own account.")}

      user.role == :admin and Accounts.admin_count() <= 1 ->
        {:noreply, put_flash(socket, :error, "The final administrator cannot be deleted.")}

      true ->
        case Accounts.delete_user(user) do
          {:ok, _user} ->
            {:noreply,
             socket
             |> put_flash(:info, "#{user.email} was permanently deleted.")
             |> load_page()}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Could not delete #{user.email}.")}
        end
    end
  end

  def handle_info(%{event: event} = payload, socket)
      when event in [
             :notification_created,
             :notification_read,
             :notification_unread,
             :notifications_read_all
           ] do
    {:noreply,
     socket
     |> Realtime.sync_unread_count(Map.get(payload, :unread_count))
     |> Realtime.track_event(payload)}
  end

  def render(assigns) do
    filtered_users = filter_users(assigns.users, assigns.role_filter, assigns.search_query)
    assigns = assign(assigns, :filtered_users, filtered_users)

    ~H"""
    <div class="space-y-6">
      <section class="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 class="text-2xl font-semibold tracking-tight text-n100">Users</h2>
          <p class="mt-1 text-sm text-n600">
            {@stats.total} total · {@stats.admin} admins · {@stats.staff} staff
          </p>
        </div>
        <button
          type="button"
          phx-click="new_user"
          class="rounded-md bg-accent px-3 py-1.5 text-sm font-medium text-white transition hover:bg-accentDeep focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/40"
        >
          New user account
        </button>
      </section>

      <section class="grid gap-4 md:grid-cols-3">
        <article class="rounded-lg border border-white/10 bg-ink p-4">
          <p class="text-sm text-n600">Total</p>
          <p class="mt-1 text-2xl font-semibold text-n100">{@stats.total}</p>
        </article>
        <article class="rounded-lg border border-white/10 bg-ink p-4">
          <p class="text-sm text-n600">Admins</p>
          <p class="mt-1 text-2xl font-semibold text-n100">{@stats.admin}</p>
        </article>
        <article class="rounded-lg border border-white/10 bg-ink p-4">
          <p class="text-sm text-n600">Staff</p>
          <p class="mt-1 text-2xl font-semibold text-n100">{@stats.staff}</p>
        </article>
      </section>

      <section class="rounded-lg border border-white/10 bg-ink p-4">
        <div class="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <.header class="!mb-0">
            All users
            <:subtitle>
              Search by name or email, filter by role, and manage each account.
            </:subtitle>
          </.header>

          <div class="flex flex-col gap-3 sm:flex-row sm:items-center">
            <div class="flex flex-wrap gap-2">
              <button
                :for={filter <- role_filters()}
                type="button"
                phx-click="filter_role"
                phx-value-filter={filter.value}
                class={filter_button_class(@role_filter, filter.value)}
              >
                {filter.label}
              </button>
            </div>

            <div class="relative">
              <span class="pointer-events-none absolute inset-y-0 left-3 flex items-center text-n600">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-4 w-4"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M21 21l-4.35-4.35M17 11A6 6 0 1 1 5 11a6 6 0 0 1 12 0z"
                  />
                </svg>
              </span>
              <input
                type="text"
                value={@search_query}
                placeholder="Search by name or email"
                phx-keyup="search_users"
                class="w-full rounded-md border border-white/10 bg-ink py-2 pl-9 pr-4 text-sm text-n100 placeholder-n600 focus:border-accent focus:outline-none focus:ring-2 focus:ring-accent/30 sm:w-72"
              />
            </div>
          </div>
        </div>

        <div
          :if={@filtered_users == []}
          class="mt-6 rounded-lg border border-dashed border-white/10 p-6 text-center text-sm leading-6 text-n600"
        >
          No user accounts match this view.
        </div>

        <div
          :if={@filtered_users != []}
          class="mt-6 divide-y divide-white/10 border-t border-white/10"
        >
          <article
            :for={user <- @filtered_users}
            class="flex flex-col gap-4 px-3 py-3 transition hover:bg-white/10 sm:flex-row sm:items-start sm:justify-between"
          >
            <div class="min-w-0 flex-1">
              <div class="flex flex-wrap items-center gap-2">
                <h3 class="text-sm font-semibold text-n100">
                  {display_name(user)}
                </h3>
                <span class={role_badge_class(user.role)}>{humanize(user.role)}</span>
                <span
                  :if={user.confirmed_at}
                  class="inline-flex items-center gap-1 text-xs font-medium text-emerald-400"
                >
                  <span class="h-1.5 w-1.5 rounded-full bg-emerald-600"></span> Confirmed
                </span>
                <span
                  :if={is_nil(user.confirmed_at)}
                  class="inline-flex items-center gap-1 text-xs font-medium text-amber-400"
                >
                  <span class="h-1.5 w-1.5 rounded-full bg-amber-600"></span> Unconfirmed
                </span>
              </div>
              <p class="mt-1 truncate text-sm text-n600">{user.email}</p>
              <p class="mt-1 text-xs text-n600">
                Joined {Calendar.strftime(user.inserted_at, "%d %b %Y")}
              </p>
              <p class="mt-3 text-sm font-medium text-n600">
                Page access
              </p>
              <p class="mt-1 text-xs text-n600">
                {access_summary(user)}
              </p>
            </div>

            <div class="flex flex-wrap gap-2">
              <button
                type="button"
                phx-click="edit_access"
                phx-value-id={user.id}
                class="rounded-md border border-white/10 bg-ink px-3 py-1.5 text-sm font-medium text-n600 transition hover:bg-white/10"
              >
                Edit access
              </button>
              <button
                type="button"
                phx-click="send_reset_password"
                phx-value-id={user.id}
                data-confirm={"Send a password reset link to #{user.email}?"}
                class="rounded-md border border-white/10 bg-ink px-3 py-1.5 text-sm font-medium text-n600 transition hover:bg-white/10"
              >
                Reset password
              </button>
              <button
                :if={is_nil(user.confirmed_at)}
                type="button"
                phx-click="send_confirmation"
                phx-value-id={user.id}
                data-confirm={"Send a confirmation email to #{user.email}?"}
                class="rounded-md border border-white/10 bg-ink px-3 py-1.5 text-sm font-medium text-n600 transition hover:bg-white/10"
              >
                Resend confirmation
              </button>
              <button
                :if={user.id != @current_user.id}
                type="button"
                phx-click="delete_user"
                phx-value-id={user.id}
                data-confirm={"Permanently delete #{user.email}? Their account access will be removed immediately. This cannot be undone."}
                class="rounded-md px-3 py-1.5 text-sm font-medium text-red-600 transition hover:bg-red-50"
              >
                Delete user
              </button>
            </div>
          </article>
        </div>
      </section>

      <.modal
        :if={@active_modal == :user}
        id="new-user-modal"
        show
        on_cancel={JS.push("close_modal", value: %{modal: "user"})}
      >
        <div class="space-y-6">
          <div>
            <h3 class="text-base font-semibold text-n100">
              New user account
            </h3>
            <p class="mt-1 text-sm text-n600">
              Create an account and grant the pages they should see.
            </p>
          </div>

          <.simple_form
            for={to_form(@user_changeset, as: :user)}
            id="new-user-form"
            phx-change="validate_user"
            phx-submit="save_user"
          >
            <div class="grid gap-5 md:grid-cols-2">
              <.input
                field={to_form(@user_changeset, as: :user)[:name]}
                type="text"
                label="Full name"
              />
              <.input
                field={to_form(@user_changeset, as: :user)[:email]}
                type="email"
                label="Email address"
              />
              <.input
                field={to_form(@user_changeset, as: :user)[:role]}
                name="user[role]"
                type="select"
                label="Role"
                options={role_options()}
                value={@new_user_role}
                phx-change="new_user_role_changed"
              />
            </div>

            <div class="space-y-4">
              <div class="flex items-center justify-between">
                <p class="text-sm font-semibold text-n100">
                  Page access
                </p>
                <p class="text-xs text-n600">
                  Admins have full access regardless of the selection below.
                </p>
              </div>

              <div class="space-y-4">
                <div
                  :for={section <- Pages.sections()}
                  class="rounded-lg border border-white/10 bg-white/10 p-4"
                >
                  <div class="flex items-center justify-between">
                    <div>
                      <p class="text-sm font-semibold text-n100">{section.label}</p>
                      <p class="text-xs text-n600">{section.description}</p>
                    </div>
                  </div>

                  <div class="mt-3 grid gap-2 sm:grid-cols-2">
                    <label
                      :for={page <- Pages.pages_in_section(section.id)}
                      class="flex items-center gap-3 rounded-md border border-white/10 bg-ink px-3 py-2 text-sm text-n600 transition hover:bg-white/10"
                    >
                      <input
                        type="checkbox"
                        phx-click="new_toggle_permission"
                        phx-value-key={Atom.to_string(page.key)}
                        checked={Atom.to_string(page.key) in @new_user_permissions}
                        class="h-4 w-4 rounded border-white/10 text-accent focus:ring-accent"
                      />
                      <span class="flex-1">{page.label}</span>
                      <span class="text-xs text-n600">
                        {page.badge}
                      </span>
                    </label>
                  </div>
                </div>
              </div>
            </div>

            <div class="rounded-lg border border-white/10 bg-white/10 px-4 py-4 text-sm leading-6 text-n600">
              A temporary password will be generated. The user will receive an email with a link to set their own password.
            </div>

            <:actions>
              <button
                type="button"
                phx-click="close_modal"
                phx-value-modal="user"
                class="rounded-md border border-white/10 bg-ink px-3 py-1.5 text-sm font-medium text-n600 transition hover:bg-white/10"
              >
                Cancel
              </button>
              <.button>
                Create user
              </.button>
            </:actions>
          </.simple_form>
        </div>
      </.modal>

      <.modal
        :if={@active_modal == :edit_access}
        id="edit-access-modal"
        show
        on_cancel={JS.push("close_modal", value: %{modal: "edit_access"})}
      >
        <div class="space-y-6">
          <div>
            <h3 class="text-base font-semibold text-n100">
              Edit access
            </h3>
            <p class="mt-1 text-sm text-n600">
              Update role and page access for {@editing_user.email}
            </p>
          </div>

          <div class="space-y-3">
            <p class="text-sm font-semibold text-n100">Role</p>
            <div class="grid gap-3 sm:grid-cols-3">
              <button
                :for={role <- [:admin, :staff]}
                type="button"
                phx-click="edit_role_select"
                phx-value-role={role}
                class={role_select_button_class(role, safe_role_atom(@editing_role))}
              >
                <span class="text-sm font-semibold">{humanize(role)}</span>
                <span class="text-xs text-n600">{role_description(role)}</span>
              </button>
            </div>
          </div>

          <div class="space-y-4">
            <div class="flex items-center justify-between">
              <p class="text-sm font-semibold text-n100">
                Page access
              </p>
              <p :if={@editing_role == "admin"} class="text-xs text-emerald-400">
                Admins have full access regardless of this selection.
              </p>
            </div>

            <div class="space-y-4">
              <div
                :for={section <- Pages.sections()}
                class="rounded-lg border border-white/10 bg-white/10 p-4"
              >
                <div class="flex items-center justify-between gap-3">
                  <div>
                    <p class="text-sm font-semibold text-n100">{section.label}</p>
                    <p class="text-xs text-n600">{section.description}</p>
                  </div>
                  <div class="flex gap-2">
                    <button
                      type="button"
                      phx-click="edit_select_all"
                      phx-value-section={section.id}
                      class="rounded-md border border-white/10 bg-ink px-2 py-1 text-xs font-medium text-n600 transition hover:bg-white/10"
                    >
                      All
                    </button>
                    <button
                      type="button"
                      phx-click="edit_clear_section"
                      phx-value-section={section.id}
                      class="rounded-md border border-white/10 bg-ink px-2 py-1 text-xs font-medium text-n600 transition hover:bg-white/10"
                    >
                      None
                    </button>
                  </div>
                </div>

                <div class="mt-3 grid gap-2 sm:grid-cols-2">
                  <label
                    :for={page <- Pages.pages_in_section(section.id)}
                    class="flex items-center gap-3 rounded-md border border-white/10 bg-ink px-3 py-2 text-sm text-n600 transition hover:bg-white/10"
                  >
                    <input
                      type="checkbox"
                      phx-click="edit_toggle_permission"
                      phx-value-key={Atom.to_string(page.key)}
                      checked={Atom.to_string(page.key) in @editing_permissions}
                      class="h-4 w-4 rounded border-white/10 text-accent focus:ring-accent"
                    />
                    <span class="flex-1">{page.label}</span>
                    <span class="text-xs text-n600">
                      {page.badge}
                    </span>
                  </label>
                </div>
              </div>
            </div>
          </div>

          <div class="flex flex-wrap justify-end gap-3">
            <button
              type="button"
              phx-click="close_modal"
              phx-value-modal="edit_access"
              class="rounded-md border border-white/10 bg-ink px-3 py-1.5 text-sm font-medium text-n600 transition hover:bg-white/10"
            >
              Cancel
            </button>
            <button
              type="button"
              phx-click="save_access"
              class="rounded-md bg-accent px-3 py-1.5 text-sm font-medium text-white transition hover:bg-accentDeep focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/40"
            >
              Save changes
            </button>
          </div>
        </div>
      </.modal>
    </div>
    """
  end

  defp load_page(socket) do
    users = Accounts.list_users()

    assign(socket,
      users: users,
      stats: %{
        total: length(users),
        admin: Enum.count(users, &(&1.role == :admin)),
        staff: Enum.count(users, &(&1.role == :staff))
      }
    )
  end

  defp reset_user_form(socket) do
    changeset =
      Accounts.change_user_registration(%User{}, %{"password" => "temporary_placeholder"})

    assign(socket,
      user_changeset: changeset,
      editing_user: nil,
      new_user_role: "staff",
      new_user_permissions: Pages.default_keys_for_role(:staff)
    )
  end

  defp filter_users(users, role_filter, search_query) do
    Enum.filter(users, fn user ->
      matches_role?(user, role_filter) and matches_search?(user, search_query)
    end)
  end

  defp matches_role?(_user, "all"), do: true
  defp matches_role?(%User{role: role}, filter), do: Atom.to_string(role) == filter

  defp matches_search?(_user, ""), do: true

  defp matches_search?(%User{} = user, query) do
    haystack =
      [user.name, user.email]
      |> Enum.map_join(" ", &to_string(&1 || ""))
      |> String.downcase()

    String.contains?(haystack, String.downcase(query))
  end

  defp role_filters do
    [
      %{label: "All", value: "all"},
      %{label: "Admin", value: "admin"},
      %{label: "Staff", value: "staff"}
    ]
  end

  defp role_options do
    [
      {"Admin", "admin"},
      {"Staff", "staff"}
    ]
  end

  defp filter_button_class(current, value) when current == value do
    "rounded-md border border-white/10 bg-white/10 px-3 py-1.5 text-sm font-medium text-n100 transition"
  end

  defp filter_button_class(_current, _value) do
    "rounded-md border border-white/10 bg-ink px-3 py-1.5 text-sm font-medium text-n600 transition hover:bg-white/10"
  end

  defp role_badge_class(:admin),
    do: "rounded px-1.5 py-0.5 text-xs font-medium bg-white/10 text-n600"

  defp role_badge_class(:staff),
    do: "rounded px-1.5 py-0.5 text-xs font-medium bg-white/10 text-n600"

  defp role_select_button_class(role, active_role) do
    base =
      "flex flex-col gap-1 rounded-md border px-4 py-3 text-left transition"

    if role == active_role do
      base <> " border-accent bg-accent text-white [&_span]:text-white"
    else
      base <> " border-white/10 bg-ink text-n600 hover:bg-white/10"
    end
  end

  defp role_description(:admin), do: "Full access to all features and settings"
  defp role_description(:staff), do: "Access is limited to the pages you grant below"

  defp temporary_password do
    12
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 16)
  end

  defp humanize(value) when is_atom(value), do: value |> Atom.to_string() |> humanize()

  defp humanize(value) when is_binary(value) do
    value
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp selected_permissions(%{"permissions" => values}, _fallback) when is_list(values) do
    Pages.sanitize_keys(values)
  end

  defp selected_permissions(_params, fallback), do: Pages.sanitize_keys(fallback)

  defp toggle_permission(list, key) do
    list = list || []

    if key in list do
      List.delete(list, key)
    else
      Enum.uniq([key | list])
    end
  end

  defp section_keys(section) when is_binary(section) do
    section_keys(String.to_existing_atom(section))
  rescue
    ArgumentError -> []
  end

  defp section_keys(section) when is_atom(section) do
    section
    |> Pages.pages_in_section()
    |> Enum.map(fn %{key: key} -> Atom.to_string(key) end)
  end

  defp safe_role_atom(role) when is_binary(role) do
    case role do
      "admin" -> :admin
      "staff" -> :staff
      _ -> nil
    end
  end

  defp safe_role_atom(_), do: nil

  defp access_summary(%User{role: :admin}), do: "Full access (admin)"

  defp access_summary(%User{permissions: []}), do: "No pages granted yet"

  defp access_summary(%User{permissions: permissions}) do
    permissions
    |> Enum.map(fn key ->
      case Pages.get(key) do
        nil -> nil
        %{label: label} -> label
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort()
    |> Enum.join(", ")
    |> case do
      "" -> "No pages granted yet"
      list -> list
    end
  end
end
