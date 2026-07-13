defmodule BetaSigma.Repo.Migrations.MakeSprintsStandalone do
  use Ecto.Migration

  def change do
    drop_if_exists index(:sprints, [:project_id])
    drop_if_exists index(:sprints, [:project_id, :start_date])
    drop_if_exists unique_index(:sprints, [:project_id, :name])

    alter table(:sprints) do
      remove :project_id, references(:projects, on_delete: :delete_all)
      add :goal, :text
    end
  end
end
