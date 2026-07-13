defmodule BetaSigmaWeb.Realtime do
  @moduledoc false

  use Phoenix.Component

  alias BetaSigma.{Chat, Notifications, Projects}

  def bootstrap(socket) do
    socket
    |> assign(:unread_count, unread_count(socket))
    |> assign(:chat_unread_count, chat_unread_count(socket))
    |> assign(:live_activity, [])
  end

  def subscribe(socket, opts \\ []) do
    if Phoenix.LiveView.connected?(socket) do
      maybe_subscribe_notifications(socket, Keyword.get(opts, :notifications, true))
      maybe_subscribe_project(socket, Keyword.get(opts, :project_id))
      maybe_subscribe_projects_workspace(Keyword.get(opts, :projects_workspace, false))
      maybe_subscribe_chat(socket, Keyword.get(opts, :chat, true))
    else
      socket
    end
  end

  def sync_unread_count(socket, unread_count \\ nil)

  def sync_unread_count(socket, unread_count) when is_integer(unread_count) do
    assign(socket, :unread_count, unread_count)
  end

  def sync_unread_count(socket, _unread_count) do
    assign(socket, :unread_count, unread_count(socket))
  end

  def track_event(socket, %{event: _event} = payload) do
    update(socket, :live_activity, fn items ->
      [build_activity(payload) | items]
      |> Enum.take(6)
    end)
  end

  def track_event(socket, _payload), do: socket

  attr :items, :list, required: true
  attr :title, :string, default: "Live activity"
  attr :subtitle, :string, default: "Incoming updates land here automatically."
  attr :empty_title, :string, default: "Waiting for activity"

  attr :empty_copy, :string,
    default: "Project and notification events will appear here as they happen."

  def live_activity_panel(assigns) do
    ~H"""
    <section class="rounded-[2rem] border border-stone-200/80 bg-white/90 p-6 shadow-[0_20px_60px_rgba(15,23,42,0.08)] backdrop-blur-sm">
      <div class="flex items-start justify-between gap-4">
        <div class="min-w-0">
          <p class="text-xs font-semibold uppercase tracking-[0.24em] text-slate-500">{@title}</p>
          <p class="mt-2 text-sm leading-6 text-slate-600 [overflow-wrap:anywhere]">{@subtitle}</p>
        </div>
        <span class="shrink-0 rounded-full border border-emerald-200 bg-emerald-50 px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.18em] text-emerald-700">
          Live
        </span>
      </div>

      <div
        :if={@items == []}
        class="mt-5 overflow-hidden rounded-[1.5rem] border border-dashed border-stone-300 bg-stone-50/80 px-5 py-6"
      >
        <p class="text-sm font-semibold text-slate-900">{@empty_title}</p>
        <p class="mt-2 text-sm leading-6 text-slate-600 [overflow-wrap:anywhere]">{@empty_copy}</p>
      </div>

      <div :if={@items != []} class="mt-5 space-y-3">
        <article
          :for={item <- @items}
          class="overflow-hidden rounded-[1.5rem] border border-stone-200 bg-stone-50/80 px-4 py-4"
        >
          <div class="flex items-start justify-between gap-4">
            <div class="min-w-0 flex-1">
              <div class="flex flex-wrap items-center gap-2">
                <span class={activity_scope_class(item.scope)}>{item.scope}</span>
                <span class="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-400">
                  {item.time}
                </span>
              </div>
              <p class="mt-3 line-clamp-2 text-sm font-semibold leading-6 text-slate-900 [overflow-wrap:anywhere]">
                {item.title}
              </p>
              <p class="mt-1 line-clamp-3 text-sm leading-6 text-slate-600 [overflow-wrap:anywhere]">
                {item.detail}
              </p>
            </div>
          </div>
        </article>
      </div>
    </section>
    """
  end

  defp maybe_subscribe_notifications(socket, true) do
    case socket.assigns[:current_user] do
      %{id: user_id} -> Notifications.subscribe(user_id)
      _other -> :ok
    end
  end

  defp maybe_subscribe_notifications(_socket, _enabled), do: :ok

  defp maybe_subscribe_project(_socket, nil), do: :ok
  defp maybe_subscribe_project(_socket, project_id), do: Projects.subscribe(project_id)

  defp maybe_subscribe_projects_workspace(true), do: Projects.subscribe_workspace()
  defp maybe_subscribe_projects_workspace(_enabled), do: :ok

  defp maybe_subscribe_chat(socket, true) do
    case socket.assigns[:current_user] do
      %{id: user_id} ->
        Chat.subscribe_user(user_id)

        socket
        |> Phoenix.LiveView.attach_hook(
          :chat_notifications,
          :handle_info,
          &handle_chat_notification/2
        )
        |> Phoenix.LiveView.push_event("chat:notify", %{
          unread_count: socket.assigns[:chat_unread_count] || 0,
          initial: true
        })

      _other ->
        socket
    end
  end

  defp maybe_subscribe_chat(socket, _enabled), do: socket

  defp handle_chat_notification(%{event: event} = _payload, socket)
       when event in [:chat_new_message, :chat_mention] do
    count = chat_unread_count(socket)

    socket =
      socket
      |> assign(:chat_unread_count, count)
      |> Phoenix.LiveView.push_event("chat:notify", %{
        unread_count: count,
        mention: event == :chat_mention
      })

    {:cont, socket}
  end

  defp handle_chat_notification(_payload, socket), do: {:cont, socket}

  defp unread_count(%{assigns: %{current_user: %{id: user_id}}}),
    do: Notifications.unread_count(user_id)

  defp unread_count(_socket), do: 0

  defp chat_unread_count(%{assigns: %{current_user: %{id: user_id}}}),
    do: Chat.total_chat_unread_count(user_id)

  defp chat_unread_count(_socket), do: 0

  defp build_activity(%{event: event} = payload) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %{
      scope: activity_scope(event),
      title: activity_title(event, payload),
      detail: activity_detail(event, payload),
      time: Calendar.strftime(now, "%H:%M:%S")
    }
  end

  defp activity_scope(event)
       when event in [
              :task_created,
              :task_updated,
              :task_deleted,
              :task_moved,
              :task_assigned,
              :task_comment_added,
              :project_created,
              :project_updated,
              :project_deleted
            ],
       do: "Projects"

  defp activity_scope(event)
       when event in [
              :notification_created,
              :notification_read,
              :notification_unread,
              :notifications_read_all
            ],
       do: "Notifications"

  defp activity_scope(_event), do: "Workspace"

  defp activity_title(:task_created, %{task: task}), do: "#{task.title} was added to the board"
  defp activity_title(:task_updated, %{task: task}), do: "#{task.title} was updated"
  defp activity_title(:task_deleted, %{task: task}), do: "#{task.title} was removed"

  defp activity_title(:task_moved, %{task: task}),
    do: "#{task.title} moved to #{humanize(task.status)}"

  defp activity_title(:task_assigned, %{task: task}), do: "Assignments changed for #{task.title}"

  defp activity_title(:task_comment_added, %{task_id: task_id}),
    do: "New discussion on task ##{task_id}"

  defp activity_title(:project_created, %{project: project}), do: "#{project.name} was created"
  defp activity_title(:project_updated, %{project: project}), do: "#{project.name} was updated"

  defp activity_title(:project_deleted, %{project: project}),
    do: "#{project.name} was archived from the list"

  defp activity_title(:notification_created, %{notification: notification}),
    do: notification.message

  defp activity_title(:notification_read, %{notification: _notification}),
    do: "Marked notification as read"

  defp activity_title(:notification_unread, %{notification: _notification}),
    do: "Marked notification as unread"

  defp activity_title(:notifications_read_all, _payload), do: "Inbox cleared"

  defp activity_title(event, _payload), do: humanize(event)

  defp activity_detail(:task_created, %{task: task}), do: task_detail(task)
  defp activity_detail(:task_updated, %{task: task}), do: task_detail(task)
  defp activity_detail(:task_deleted, %{task: task}), do: task_detail(task)
  defp activity_detail(:task_moved, %{task: task}), do: task_detail(task)
  defp activity_detail(:task_assigned, %{task: task}), do: task_detail(task)
  defp activity_detail(:task_comment_added, %{comment: comment}), do: comment.body

  defp activity_detail(:project_created, %{project: project}),
    do: project.description || "Project shell is ready for task planning."

  defp activity_detail(:project_updated, %{project: project}),
    do: project.description || "Project details changed."

  defp activity_detail(:project_deleted, %{project: project}),
    do: project.description || "Project removed from the active portfolio."

  defp activity_detail(:notification_created, %{notification: notification}),
    do: notification.link || "A new workflow alert was delivered."

  defp activity_detail(:notification_read, %{unread_count: unread_count}),
    do: unread_detail(unread_count)

  defp activity_detail(:notification_unread, %{unread_count: unread_count}),
    do: unread_detail(unread_count)

  defp activity_detail(:notifications_read_all, %{unread_count: unread_count}),
    do: unread_detail(unread_count)

  defp activity_detail(_event, _payload), do: "Live workspace event received."

  defp task_detail(task) do
    [
      task.project && task.project.name,
      humanize(task.status),
      "#{length(task.assignees || [])} assignee(s)"
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" • ")
  end

  defp unread_detail(unread_count) when is_integer(unread_count),
    do: "#{unread_count} unread notification(s) remaining."

  defp unread_detail(_unread_count), do: "Notification state changed."

  defp activity_scope_class("Projects"),
    do:
      "rounded-full bg-amber-100 px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.18em] text-amber-700"

  defp activity_scope_class("Notifications"),
    do:
      "rounded-full bg-rose-100 px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.18em] text-rose-700"

  defp activity_scope_class(_scope),
    do:
      "rounded-full bg-stone-100 px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-600"

  defp humanize(value) when is_atom(value), do: value |> Atom.to_string() |> humanize()

  defp humanize(value) when is_binary(value) do
    value
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
