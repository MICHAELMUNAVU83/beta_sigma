defmodule BetaSigma.Discovery.Module do
  @moduledoc """
  A group of related questions inside a department, rendered as one tab.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "discovery_modules" do
    field :slug, :string
    field :name, :string
    field :intro, :string
    field :position, :integer, default: 0

    belongs_to :department, BetaSigma.Discovery.Department
    has_many :questions, BetaSigma.Discovery.Question, preload_order: [asc: :position]

    timestamps(type: :utc_datetime)
  end

  def changeset(module, attrs) do
    module
    |> cast(attrs, [:department_id, :slug, :name, :intro, :position])
    |> validate_required([:department_id, :slug, :name])
    |> unique_constraint([:department_id, :slug])
    |> foreign_key_constraint(:department_id)
  end
end
