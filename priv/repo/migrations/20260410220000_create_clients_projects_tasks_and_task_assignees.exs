defmodule BetaSigma.Repo.Migrations.CreateClientsProjectsTasksAndTaskAssignees do
  use Ecto.Migration

  def change do
    create table(:clients) do
      add :name, :string, null: false
      add :company, :string
      add :email, :string
      add :phone, :string
      add :country, :string, null: false, default: "Kenya"
      add :industry, :string

      timestamps(type: :utc_datetime)
    end

    create index(:clients, [:name])

    create table(:projects) do
      add :name, :string, null: false
      add :description, :text
      add :status, :string, null: false, default: "planning"
      add :start_date, :date
      add :deadline, :date
      add :budget, :decimal, precision: 15, scale: 2
      add :client_id, references(:clients, on_delete: :nilify_all)
      add :created_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:projects, [:client_id])
    create index(:projects, [:created_by_id])
    create index(:projects, [:status])
    create index(:projects, [:deadline])

    create table(:tasks) do
      add :title, :string, null: false
      add :description, :text
      add :status, :string, null: false, default: "backlog"
      add :priority, :string, null: false, default: "medium"
      add :due_date, :date
      add :estimated_hours, :decimal, precision: 5, scale: 2
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :created_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:tasks, [:project_id])
    create index(:tasks, [:status])
    create index(:tasks, [:created_by_id])
    create index(:tasks, [:due_date])

    create table(:task_assignees, primary_key: false) do
      add :task_id, references(:tasks, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
    end

    create unique_index(:task_assignees, [:task_id, :user_id])
    create index(:task_assignees, [:user_id])
  end
end
