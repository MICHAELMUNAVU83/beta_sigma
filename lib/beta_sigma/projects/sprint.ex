defmodule BetaSigma.Projects.Sprint do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sprints" do
    field :name, :string
    field :goal, :string
    field :cadence, Ecto.Enum, values: [:weekly, :biweekly], default: :weekly
    field :start_date, :date
    field :end_date, :date

    belongs_to :created_by, BetaSigma.Accounts.User

    has_many :tasks, BetaSigma.Projects.Task

    timestamps(type: :utc_datetime)
  end

  def changeset(sprint, attrs) do
    sprint
    |> cast(attrs, [:name, :goal, :cadence, :start_date, :created_by_id])
    |> validate_required([:name, :cadence, :start_date])
    |> validate_length(:name, max: 160)
    |> maybe_put_end_date()
    |> validate_required([:end_date])
    |> validate_end_date_after_start()
    |> foreign_key_constraint(:created_by_id)
  end

  defp maybe_put_end_date(changeset) do
    cadence = get_field(changeset, :cadence)
    start_date = get_field(changeset, :start_date)

    if is_nil(cadence) or is_nil(start_date) do
      changeset
    else
      duration_days =
        case cadence do
          :weekly -> 7
          :biweekly -> 14
        end

      put_change(changeset, :end_date, Date.add(start_date, duration_days - 1))
    end
  end

  defp validate_end_date_after_start(changeset) do
    start_date = get_field(changeset, :start_date)
    end_date = get_field(changeset, :end_date)

    cond do
      is_nil(start_date) or is_nil(end_date) ->
        changeset

      Date.compare(end_date, start_date) in [:gt, :eq] ->
        changeset

      true ->
        add_error(changeset, :end_date, "must be on or after the start date")
    end
  end
end
