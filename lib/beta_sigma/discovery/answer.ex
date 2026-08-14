defmodule BetaSigma.Discovery.Answer do
  @moduledoc """
  One answer within a session, plus the build context captured alongside it:
  confidence, build priority, owner, which companies it applies to, a
  follow-up date, and the evidence backing it.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @confidences ["Confirmed", "Needs follow-up", "Working assumption", "Not discussed"]
  @priorities ["Must have at launch", "Should have", "Later", "Not needed"]
  @applies_to [
    "Whole group",
    "Sichangi Law Alliance",
    "Tukutane",
    "Chasing Sun",
    "Different by company",
    "Not confirmed"
  ]

  schema "discovery_answers" do
    field :value, :string
    field :values, {:array, :string}, default: []
    field :note, :string
    field :confidence, :string
    field :priority, :string
    field :owner, :string
    field :applies_to, :string
    field :follow_up_on, :date
    field :evidence, :string

    belongs_to :session, BetaSigma.Discovery.Session
    belongs_to :question, BetaSigma.Discovery.Question
    belongs_to :answered_by, BetaSigma.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def confidences, do: @confidences
  def priorities, do: @priorities
  def applies_to_options, do: @applies_to

  @doc "True when the answer carries an actual response (metadata alone does not count)."
  def answered?(nil), do: false
  def answered?(%__MODULE__{values: values}) when values != [], do: true
  def answered?(%__MODULE__{value: value}), do: is_binary(value) and String.trim(value) != ""

  def changeset(answer, attrs) do
    answer
    |> cast(attrs, [
      :session_id,
      :question_id,
      :value,
      :values,
      :note,
      :confidence,
      :priority,
      :owner,
      :applies_to,
      :follow_up_on,
      :evidence,
      :answered_by_id
    ])
    |> blank_to_nil([:confidence, :priority, :applies_to])
    |> validate_required([:session_id, :question_id])
    |> validate_inclusion(:confidence, @confidences)
    |> validate_inclusion(:priority, @priorities)
    |> validate_inclusion(:applies_to, @applies_to)
    |> unique_constraint([:session_id, :question_id])
    |> foreign_key_constraint(:session_id)
    |> foreign_key_constraint(:question_id)
  end

  # The workspace sends "" for the "Choose…" option; store that as nil so the
  # inclusion validations (and reports) treat it as unset.
  defp blank_to_nil(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, acc ->
      case get_change(acc, field) do
        "" -> put_change(acc, field, nil)
        _ -> acc
      end
    end)
  end
end
