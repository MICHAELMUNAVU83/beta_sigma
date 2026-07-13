defmodule BetaSigma.Repo.Migrations.CreateTaskCommentsAndNotes do
  use Ecto.Migration

  def change do
    create table(:task_comments) do
      add :body, :text, null: false
      add :task_id, references(:tasks, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:task_comments, [:task_id])
    create index(:task_comments, [:user_id])
    create index(:task_comments, [:inserted_at])

    create table(:notes) do
      add :title, :string, null: false
      add :body, :text
      add :visibility, :string, null: false, default: "personal"
      add :project_id, references(:projects, on_delete: :nilify_all)
      add :task_id, references(:tasks, on_delete: :nilify_all)
      add :created_by_id, references(:users, on_delete: :nilify_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:notes, [:visibility])
    create index(:notes, [:project_id])
    create index(:notes, [:task_id])
    create index(:notes, [:created_by_id])
  end
end
