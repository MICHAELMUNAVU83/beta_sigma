# credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
# credo:disable-for-this-file Credo.Check.Refactor.Nesting
defmodule BetaSigmaWeb.WorkspaceLive do
  use BetaSigmaWeb, :live_view

  alias BetaSigma.Notifications
  alias BetaSigmaWeb.Realtime

  @pages %{
    notifications: %{
      title: "Notifications",
      subtitle: "The unread center and real-time workflow updates will live on this route.",
      bullets: [
        "Unread inbox",
        "Task reminders",
        "Cross-module alert stream"
      ]
    }
  }

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> Realtime.bootstrap()
     |> Realtime.subscribe(projects_workspace: true)}
  end

  def handle_params(_params, _uri, socket) do
    page = Map.fetch!(@pages, socket.assigns.live_action)

    {:noreply,
     socket
     |> assign(:page, page)
     |> assign(:page_title, page.title)
     |> load_page()}
  end

  def handle_event("mark_all_read", _params, socket) do
    Notifications.mark_all_read(socket.assigns.current_user.id)

    {:noreply,
     socket
     |> put_flash(:info, "All notifications marked as read.")
     |> load_page()}
  end

  def handle_event("toggle_notification", %{"id" => id}, socket) do
    notification = Notifications.get_notification!(id)

    if notification.user_id != socket.assigns.current_user.id do
      {:noreply, put_flash(socket, :error, "You cannot update another user's notifications.")}
    else
      case if(notification.read,
             do: Notifications.mark_unread(notification),
             else: Notifications.mark_read(notification)
           ) do
        {:ok, _notification} ->
          {:noreply, load_page(socket)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Notification could not be updated.")}
      end
    end
  end

  def handle_info(%{event: _event} = payload, socket) do
    {:noreply,
     socket
     |> Realtime.sync_unread_count(Map.get(payload, :unread_count))
     |> Realtime.track_event(payload)
     |> load_page()}
  end

  def render(assigns) do
    ~H"""
    <div :if={@live_action == :notifications} class="max-w-5xl space-y-6">
      <section class="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 class="text-2xl font-semibold tracking-tight text-neutral-900">Notifications</h2>
          <p class="mt-1 text-sm text-neutral-500">
            {@unread_count} unread · {@notification_stats.total} total
          </p>
        </div>
      </section>

      <section class="grid gap-4 md:grid-cols-3">
        <article class="rounded-lg border border-neutral-200 bg-white p-4">
          <p class="text-sm font-medium text-neutral-500">Unread</p>
          <p class="mt-1 text-2xl font-semibold text-neutral-900">
            {@notification_stats.unread}
          </p>
        </article>
        <article class="rounded-lg border border-neutral-200 bg-white p-4">
          <p class="text-sm font-medium text-neutral-500">
            Linked alerts
          </p>
          <p class="mt-1 text-2xl font-semibold text-neutral-900">
            {@notification_stats.linked}
          </p>
        </article>
        <article class="rounded-lg border border-neutral-200 bg-white p-4">
          <p class="text-sm font-medium text-neutral-500">
            Live feed items
          </p>
          <p class="mt-1 text-2xl font-semibold text-neutral-900">
            {length(@live_activity)}
          </p>
        </article>
      </section>

      <div class="grid gap-6">
        <section class="rounded-lg border border-neutral-200 bg-white p-4">
          <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h3 class="text-sm font-semibold text-neutral-900">Inbox</h3>
              <p class="mt-1 text-sm text-neutral-500">
                Mark alerts read or unread and jump back into the linked workflow.
              </p>
            </div>

            <button
              :if={@notification_stats.unread > 0}
              type="button"
              phx-click="mark_all_read"
              class="rounded-md border border-neutral-200 bg-white px-3 py-1.5 text-sm font-medium text-neutral-700 hover:bg-neutral-50"
            >
              Mark all read
            </button>
          </div>

          <div class="mt-4 divide-y divide-neutral-200 border-t border-neutral-200">
            <article :for={notification <- @notifications} class="px-3 py-2 hover:bg-neutral-50">
              <div class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                <div>
                  <div class="flex flex-wrap items-center gap-2">
                    <span
                      :if={!notification.read}
                      class="h-2 w-2 rounded-full bg-[#f26334]"
                      aria-label="Unread"
                    >
                    </span>
                    <span class={notification_type_badge(notification.type)}>
                      {humanize(notification.type || "update")}
                    </span>
                  </div>
                  <p class="mt-2 text-sm font-medium text-neutral-900">{notification.message}</p>
                  <p class="mt-1 text-xs text-neutral-500">
                    {Calendar.strftime(notification.inserted_at, "%d %b %Y • %H:%M")}
                  </p>
                </div>

                <div class="flex flex-wrap gap-2">
                  <.link
                    :if={notification.link}
                    navigate={notification.link}
                    class="rounded-md border border-neutral-200 bg-white px-3 py-1.5 text-sm font-medium text-neutral-700 hover:bg-neutral-50"
                  >
                    Open
                  </.link>
                  <button
                    type="button"
                    phx-click="toggle_notification"
                    phx-value-id={notification.id}
                    class="rounded-md px-2 py-1.5 text-sm font-medium text-neutral-500 hover:bg-neutral-100"
                  >
                    {if(notification.read, do: "Mark unread", else: "Mark read")}
                  </button>
                </div>
              </div>
            </article>
            <div
              :if={@notifications == []}
              class="rounded-lg border border-dashed border-neutral-200 p-6 text-center"
            >
              <p class="text-sm text-neutral-500">No notifications yet.</p>
            </div>
          </div>
        </section>
      </div>
    </div>
    """
  end

  defp load_page(socket) do
    case socket.assigns.live_action do
      :notifications -> load_notifications_page(socket)
    end
  end

  defp load_notifications_page(socket) do
    notifications = Notifications.list_notifications(socket.assigns.current_user.id)

    assign(socket,
      notifications: notifications,
      notification_stats: %{
        total: length(notifications),
        unread: Enum.count(notifications, &(!&1.read)),
        linked: Enum.count(notifications, &(is_binary(&1.link) and &1.link != ""))
      }
    )
  end

  defp notification_type_badge(_type),
    do: "rounded bg-neutral-100 px-1.5 py-0.5 text-xs font-medium text-neutral-600"

  defp humanize(value) when is_atom(value), do: value |> Atom.to_string() |> humanize()

  defp humanize(value) when is_binary(value) do
    value
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
