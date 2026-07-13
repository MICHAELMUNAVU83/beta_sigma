defmodule BetaSigma.Automation do
  @moduledoc """
  Queues and emits cross-module workflow notifications.
  """

  alias Oban
  alias BetaSigma.{Accounts, Notifications}
  alias BetaSigma.Accounts.User

  alias BetaSigma.Workers.{
    ProjectMentionWorker,
    TaskMentionWorker,
    TaskReminderWorker
  }

  def handle_task_assigned(task, newly_assigned_ids \\ nil) do
    task.assignees
    |> newly_tagged_assignees(newly_assigned_ids)
    |> Enum.each(fn assignee ->
      Notifications.create_notification(
        assignee.id,
        "task_assigned",
        "#{task.title} was assigned to you in #{task.project.name}.",
        "/app/projects/#{task.project_id}"
      )

      _ = enqueue_task_assignment_email(task.id, assignee.id)
    end)

    :ok
  end

  # When the caller does not specify which assignees are new (e.g. a fresh task),
  # treat every current assignee as newly tagged.
  defp newly_tagged_assignees(assignees, nil), do: assignees

  defp newly_tagged_assignees(assignees, newly_assigned_ids),
    do: Enum.filter(assignees, &(&1.id in newly_assigned_ids))

  def handle_task_mentioned(task, user_ids) do
    user_ids
    |> mentionable_users()
    |> Enum.each(fn user ->
      Notifications.create_notification(
        user.id,
        "task_mention",
        "You were mentioned in #{task.title} in #{task.project.name}.",
        "/app/projects/#{task.project_id}"
      )

      _ = enqueue_task_mention_email(task.id, user.id)
    end)

    :ok
  end

  def handle_project_mentioned(project, user_ids) do
    user_ids
    |> mentionable_users()
    |> Enum.each(fn user ->
      Notifications.create_notification(
        user.id,
        "project_mention",
        "You were mentioned in the #{project.name} project.",
        "/app/projects/#{project.id}"
      )

      _ = enqueue_project_mention_email(project.id, user.id)
    end)

    :ok
  end

  defp mentionable_users([]), do: []

  defp mentionable_users(user_ids) do
    Accounts.list_users()
    |> Enum.filter(&(&1.id in user_ids and User.has_role?(&1, [:admin, :staff])))
  end

  def notify_task_reminder(user, task, mode \\ :scheduled) do
    type = if mode == :assignment, do: "task_assigned", else: "task_reminder"

    message =
      if mode == :assignment do
        "#{task.title} was assigned to you in #{task.project.name}."
      else
        "#{task.title} is due on #{format_date(task.due_date)} in #{task.project.name}."
      end

    Notifications.create_notification(user.id, type, message, "/app/projects/#{task.project_id}")
  end

  defp enqueue_task_assignment_email(task_id, user_id) do
    TaskReminderWorker.new(%{
      "task_id" => task_id,
      "user_id" => user_id,
      "mode" => "assignment"
    })
    |> Oban.insert()
  end

  defp enqueue_task_mention_email(task_id, user_id) do
    TaskMentionWorker.new(%{"task_id" => task_id, "user_id" => user_id})
    |> Oban.insert()
  end

  defp enqueue_project_mention_email(project_id, user_id) do
    ProjectMentionWorker.new(%{"project_id" => project_id, "user_id" => user_id})
    |> Oban.insert()
  end

  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d %b %Y")
  defp format_date(_date), do: "an upcoming date"
end
