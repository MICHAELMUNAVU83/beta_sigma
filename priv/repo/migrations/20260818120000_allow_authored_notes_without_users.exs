defmodule BetaSigma.Repo.Migrations.AllowAuthoredNotesWithoutUsers do
  use Ecto.Migration

  def change do
    alter table(:notes) do
      modify :created_by_id, :bigint, null: true
    end
  end
end
