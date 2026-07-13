defmodule BetaSigma.Notes.Note do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notes" do
    field :title, :string
    field :body, :string
    field :visibility, Ecto.Enum, values: [:personal, :shared], default: :personal

    belongs_to :project, BetaSigma.Projects.Project
    belongs_to :task, BetaSigma.Projects.Task
    belongs_to :created_by, BetaSigma.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(note, attrs) do
    note
    |> cast(attrs, [:title, :body, :visibility, :project_id, :task_id, :created_by_id])
    |> validate_required([:title, :visibility, :created_by_id])
    |> validate_length(:title, max: 200)
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:task_id)
    |> foreign_key_constraint(:created_by_id)
  end
end
