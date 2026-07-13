defmodule BetaSigma.Projects.Project do
  use Ecto.Schema
  import Ecto.Changeset

  schema "projects" do
    field :name, :string
    field :description, :string
    field :ai_prompt, :string, virtual: true

    field :status, Ecto.Enum,
      values: [:planning, :active, :on_hold, :completed, :archived],
      default: :planning

    field :start_date, :date
    field :deadline, :date
    field :budget, :decimal

    belongs_to :created_by, BetaSigma.Accounts.User

    has_many :tasks, BetaSigma.Projects.Task
    has_many :notes, BetaSigma.Notes.Note

    timestamps(type: :utc_datetime)
  end

  def changeset(project, attrs) do
    project
    |> cast(attrs, [
      :name,
      :description,
      :ai_prompt,
      :status,
      :start_date,
      :deadline,
      :budget,
      :created_by_id
    ])
    |> validate_required([:name, :status])
    |> validate_length(:name, max: 160)
    |> validate_length(:ai_prompt, max: 4_000)
    |> validate_number(:budget, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:created_by_id)
  end
end
