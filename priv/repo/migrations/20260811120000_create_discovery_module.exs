defmodule BetaSigma.Repo.Migrations.CreateDiscoveryModule do
  use Ecto.Migration

  def change do
    create table(:discovery_departments) do
      add :scope, :string, null: false
      add :slug, :string, null: false
      add :name, :string, null: false
      add :summary, :text
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:discovery_departments, [:slug])
    create index(:discovery_departments, [:scope])

    create table(:discovery_modules) do
      add :department_id, references(:discovery_departments, on_delete: :delete_all), null: false
      add :slug, :string, null: false
      add :name, :string, null: false
      add :intro, :text
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:discovery_modules, [:department_id, :slug])

    create table(:discovery_questions) do
      add :module_id, references(:discovery_modules, on_delete: :delete_all), null: false
      add :slug, :string, null: false
      add :label, :text, null: false
      add :hint, :text
      add :type, :string, null: false
      add :options, {:array, :string}, null: false, default: []
      add :placeholder, :string
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:discovery_questions, [:module_id, :slug])

    create table(:discovery_sessions) do
      add :department_id, references(:discovery_departments, on_delete: :delete_all), null: false
      add :interviewee, :string
      add :interviewee_role, :string
      add :interviewer, :string
      add :held_on, :date
      add :status, :string, null: false, default: "in_progress"
      add :created_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:discovery_sessions, [:department_id])
    create index(:discovery_sessions, [:created_by_id])
    create index(:discovery_sessions, [:status])

    create table(:discovery_answers) do
      add :session_id, references(:discovery_sessions, on_delete: :delete_all), null: false
      add :question_id, references(:discovery_questions, on_delete: :delete_all), null: false
      # Free text/number answers land in :value; multi-select answers in :values.
      add :value, :text
      add :values, {:array, :string}, null: false, default: []
      add :note, :text
      add :confidence, :string
      add :priority, :string
      add :owner, :string
      add :applies_to, :string
      add :follow_up_on, :date
      add :evidence, :text
      add :answered_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:discovery_answers, [:session_id, :question_id])
    create index(:discovery_answers, [:question_id])
    create index(:discovery_answers, [:priority])
    create index(:discovery_answers, [:confidence])
  end
end
