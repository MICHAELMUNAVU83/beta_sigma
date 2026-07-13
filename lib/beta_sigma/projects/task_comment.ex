defmodule BetaSigma.Projects.TaskComment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "task_comments" do
    field :body, :string

    belongs_to :task, BetaSigma.Projects.Task
    belongs_to :user, BetaSigma.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(task_comment, attrs) do
    task_comment
    |> cast(attrs, [:body, :task_id, :user_id])
    |> validate_required([:body, :task_id])
    |> validate_length(:body, min: 1)
    |> foreign_key_constraint(:task_id)
    |> foreign_key_constraint(:user_id)
  end
end
