defmodule BetaSigma.Projects.Task do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tasks" do
    field :title, :string
    field :description, :string
    field :phase, :string
    field :status, Ecto.Enum, values: [:backlog, :in_progress, :review, :done], default: :backlog
    field :priority, Ecto.Enum, values: [:low, :medium, :high, :urgent], default: :medium
    field :due_date, :date
    field :estimated_hours, :decimal

    belongs_to :project, BetaSigma.Projects.Project
    belongs_to :sprint, BetaSigma.Projects.Sprint
    belongs_to :created_by, BetaSigma.Accounts.User

    has_many :task_assignees, BetaSigma.Projects.TaskAssignee

    many_to_many :assignees, BetaSigma.Accounts.User,
      join_through: BetaSigma.Projects.TaskAssignee

    has_many :comments, BetaSigma.Projects.TaskComment
    has_many :notes, BetaSigma.Notes.Note

    timestamps(type: :utc_datetime)
  end

  def changeset(task, attrs) do
    task
    |> cast(attrs, [
      :title,
      :description,
      :phase,
      :status,
      :priority,
      :due_date,
      :estimated_hours,
      :project_id,
      :sprint_id,
      :created_by_id
    ])
    |> validate_required([:title, :status, :priority, :project_id])
    |> validate_length(:title, max: 200)
    |> validate_length(:phase, max: 100)
    |> validate_number(:estimated_hours, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:sprint_id)
    |> foreign_key_constraint(:created_by_id)
  end
end
