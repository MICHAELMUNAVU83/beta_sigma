defmodule BetaSigma.Workers.TaskMentionWorker do
  @moduledoc false

  use Oban.Worker, queue: :mailers, max_attempts: 5

  alias BetaSigma.Accounts
  alias BetaSigma.Notifications.EmailNotifier
  alias BetaSigma.Projects

  @impl true
  def perform(%Oban.Job{args: %{"task_id" => task_id, "user_id" => user_id}}) do
    task = Projects.get_task!(task_id)

    case Accounts.get_user!(user_id) do
      %{email: email} when is_binary(email) ->
        _ = EmailNotifier.deliver_task_mention(email, task)
        :ok

      _ ->
        :ok
    end
  end
end
