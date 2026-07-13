defmodule BetaSigma.Projects.TaskAssignee do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "task_assignees" do
    belongs_to :task, BetaSigma.Projects.Task, primary_key: true
    belongs_to :user, BetaSigma.Accounts.User, primary_key: true
  end

  def changeset(task_assignee, attrs) do
    task_assignee
    |> cast(attrs, [:task_id, :user_id])
    |> validate_required([:task_id, :user_id])
    |> unique_constraint([:task_id, :user_id])
    |> foreign_key_constraint(:task_id)
    |> foreign_key_constraint(:user_id)
  end
end
