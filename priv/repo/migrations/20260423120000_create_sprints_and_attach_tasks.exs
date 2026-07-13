defmodule BetaSigma.Repo.Migrations.CreateSprintsAndAttachTasks do
  use Ecto.Migration

  def change do
    create table(:sprints) do
      add :name, :string, null: false
      add :cadence, :string, null: false, default: "weekly"
      add :start_date, :date, null: false
      add :end_date, :date, null: false
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :created_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:sprints, [:project_id])
    create index(:sprints, [:project_id, :start_date])
    create unique_index(:sprints, [:project_id, :name])

    alter table(:tasks) do
      add :sprint_id, references(:sprints, on_delete: :nilify_all)
    end

    create index(:tasks, [:sprint_id])
    create index(:tasks, [:project_id, :sprint_id])
  end
end
