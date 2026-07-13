defmodule BetaSigma.Workers.ProjectMentionWorker do
  @moduledoc false

  use Oban.Worker, queue: :mailers, max_attempts: 5

  alias BetaSigma.Accounts
  alias BetaSigma.Notifications.EmailNotifier
  alias BetaSigma.Projects

  @impl true
  def perform(%Oban.Job{args: %{"project_id" => project_id, "user_id" => user_id}}) do
    project = Projects.get_project!(project_id)

    case Accounts.get_user!(user_id) do
      %{email: email} when is_binary(email) ->
        _ = EmailNotifier.deliver_project_mention(email, project)
        :ok

      _ ->
        :ok
    end
  end
end
