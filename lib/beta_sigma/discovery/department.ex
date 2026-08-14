defmodule BetaSigma.Discovery.Department do
  @moduledoc """
  A department (or company) being interviewed, e.g. Group Finance or Tukutane.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @scopes [:group, :company]

  schema "discovery_departments" do
    field :scope, Ecto.Enum, values: @scopes
    field :slug, :string
    field :name, :string
    field :summary, :string
    field :position, :integer, default: 0

    has_many :modules, BetaSigma.Discovery.Module, preload_order: [asc: :position]
    has_many :sessions, BetaSigma.Discovery.Session

    timestamps(type: :utc_datetime)
  end

  def scopes, do: @scopes

  def changeset(department, attrs) do
    department
    |> cast(attrs, [:scope, :slug, :name, :summary, :position])
    |> validate_required([:scope, :slug, :name])
    |> unique_constraint(:slug)
  end
end
