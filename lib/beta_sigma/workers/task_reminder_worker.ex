defmodule BetaSigma.Workers.TaskReminderWorker do
  @moduledoc false

  use Oban.Worker, queue: :mailers, max_attempts: 5

  alias BetaSigma.{Automation, Projects}
  alias BetaSigma.Notifications.EmailNotifier

  @impl true
  def perform(%Oban.Job{args: %{"task_id" => task_id, "user_id" => user_id} = args}) do
    task = Projects.get_task!(task_id)

    case Enum.find(task.assignees, &(&1.id == user_id)) do
      nil -> :ok
      user -> deliver_assignment_email(task, user, task_mode(args))
    end

    :ok
  end

  def perform(%Oban.Job{args: args}) do
    mode = task_mode(args)

    args
    |> tasks_to_process()
    |> Enum.each(fn task -> deliver_reminders(task, mode) end)

    :ok
  end

  defp tasks_to_process(%{"task_id" => task_id}) do
    [Projects.get_task!(task_id)]
  end

  defp tasks_to_process(_args) do
    cutoff = Date.add(Date.utc_today(), 2)

    Projects.list_projects()
    |> Enum.flat_map(&Projects.list_tasks(&1.id, due_before: cutoff))
    |> Enum.filter(&remindable_task?/1)
  end

  defp deliver_reminders(task, mode) do
    Enum.each(task.assignees, fn user ->
      _ = EmailNotifier.deliver_task_reminder(user.email, task, mode: mode)
      Automation.notify_task_reminder(user, task, mode)
    end)
  end

  # Assignment ("tagging") emails target a single newly tagged assignee. The
  # in-app notification is already created in Automation.handle_task_assigned/2,
  # so here we only deliver the email.
  defp deliver_assignment_email(task, user, mode) do
    _ = EmailNotifier.deliver_task_reminder(user.email, task, mode: mode)
    :ok
  end

  defp remindable_task?(task) do
    match?(%Date{}, task.due_date) and task.status != :done and task.assignees != []
  end

  defp task_mode(%{"mode" => "assignment"}), do: :assignment
  defp task_mode(_args), do: :scheduled
end
