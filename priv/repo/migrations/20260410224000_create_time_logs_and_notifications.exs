defmodule BetaSigma.Repo.Migrations.CreateTimeLogsAndNotifications do
  use Ecto.Migration

  def change do
    create table(:time_logs) do
      add :date, :date, null: false
      add :hours, :decimal, precision: 5, scale: 2, null: false
      add :description, :string
      add :billed, :boolean, null: false, default: false
      add :project_id, references(:projects, on_delete: :nilify_all)
      add :task_id, references(:tasks, on_delete: :nilify_all)
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:time_logs, [:project_id])
    create index(:time_logs, [:task_id])
    create index(:time_logs, [:user_id])
    create index(:time_logs, [:user_id, :date])
    create index(:time_logs, [:billed])

    create table(:notifications) do
      add :type, :string
      add :message, :string, null: false
      add :link, :string
      add :read, :boolean, null: false, default: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:notifications, [:user_id, :read])
    create index(:notifications, [:type])
  end
end
