defmodule BetaSigma.Discovery.Question do
  @moduledoc """
  A single discovery question. `type` decides which control the workspace
  renders and whether answers land in `value` or `values`.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @types [:text, :number, :select, :radio, :checks]

  schema "discovery_questions" do
    field :slug, :string
    field :label, :string
    field :hint, :string
    field :type, Ecto.Enum, values: @types
    field :options, {:array, :string}, default: []
    field :placeholder, :string
    field :position, :integer, default: 0

    belongs_to :module, BetaSigma.Discovery.Module
    has_many :answers, BetaSigma.Discovery.Answer

    timestamps(type: :utc_datetime)
  end

  def types, do: @types

  @doc "True when answers to this question are stored in `values`."
  def multi?(%__MODULE__{type: :checks}), do: true
  def multi?(%__MODULE__{}), do: false

  def changeset(question, attrs) do
    question
    |> cast(attrs, [
      :module_id,
      :slug,
      :label,
      :hint,
      :type,
      :options,
      :placeholder,
      :position
    ])
    |> validate_required([:module_id, :slug, :label, :type])
    |> unique_constraint([:module_id, :slug])
    |> foreign_key_constraint(:module_id)
  end
end
