defmodule BetaSigma.Notifications.EmailNotifier do
  @moduledoc """
  Workflow emails delivered through the Resend-backed mailer.
  """

  alias BetaSigma.Mailer

  def deliver_task_reminder(recipient, task, opts \\ []) do
    mode = Keyword.get(opts, :mode, :scheduled)

    subject_prefix = if mode == :assignment, do: "New task assigned", else: "Task reminder"

    deliver(recipient, "#{subject_prefix}: #{task.title}", %{
      eyebrow: "Project workflow",
      preheader: "#{task.title} needs attention in the project workspace.",
      title: subject_prefix,
      intro: "#{task.title} is ready for follow-up in #{task.project.name}.",
      body:
        "Open the project workspace to review progress, update status, and continue the work.",
      details: [
        {"Task", task.title},
        {"Project", task.project.name},
        {"Status", humanize(task.status)},
        {"Due date", format_date(task.due_date)}
      ],
      footer_note: "Project workflow notification from BetaSigma."
    })
  end

  def deliver_task_mention(recipient, task) do
    deliver(recipient, "You were mentioned: #{task.title}", %{
      eyebrow: "Project workflow",
      preheader: "You were mentioned on #{task.title} in #{task.project.name}.",
      title: "You were mentioned in a task",
      intro: "You were mentioned on #{task.title} in #{task.project.name}.",
      body:
        "Open the project workspace to see the full context and pick up where the conversation left off.",
      details: [
        {"Task", task.title},
        {"Project", task.project.name},
        {"Status", humanize(task.status)},
        {"Due date", format_date(task.due_date)}
      ],
      footer_note: "Project workflow notification from BetaSigma."
    })
  end

  def deliver_project_mention(recipient, project) do
    deliver(recipient, "You were mentioned: #{project.name}", %{
      eyebrow: "Project workflow",
      preheader: "You were mentioned in the #{project.name} project.",
      title: "You were mentioned in a project",
      intro: "You were mentioned in the #{project.name} project description.",
      body:
        "Open the project workspace to see the full context and pick up where the conversation left off.",
      details: [
        {"Project", project.name},
        {"Status", humanize(project.status)}
      ],
      footer_note: "Project workflow notification from BetaSigma."
    })
  end

  defp deliver(recipient, subject, attrs) do
    Mailer.deliver(Map.merge(attrs, %{to: recipient, subject: subject}))
  end

  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d %b %Y")
  defp format_date(_date), do: "Not set"

  defp humanize(value) when is_atom(value), do: value |> Atom.to_string() |> humanize()

  defp humanize(value) when is_binary(value) do
    value
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
