defmodule BetaSigma.Repo.Migrations.CreateAdminSettings do
  use Ecto.Migration

  def change do
    create table(:admin_settings) do
      add :key, :string, null: false
      add :value, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:admin_settings, [:key])
  end
end
