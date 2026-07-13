defmodule BetaSigma.Repo.Migrations.CreateJobAptitudeTables do
  use Ecto.Migration

  def change do
    create table(:job_aptitude_assessments) do
      add :title, :string, null: false
      add :overview, :text
      add :instructions, {:array, :string}, null: false, default: []
      add :question_count, :integer, null: false, default: 0
      add :time_limit_minutes, :integer, null: false, default: 30
      add :difficulty, :string
      add :status, :string, null: false, default: "draft"
      add :version, :integer, null: false, default: 1
      add :assessment_payload, :map, null: false
      add :last_sent_at, :utc_datetime
      add :job_listing_id, references(:job_listings, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:job_aptitude_assessments, [:job_listing_id])
    create index(:job_aptitude_assessments, [:status])
    create unique_index(:job_aptitude_assessments, [:job_listing_id, :version])

    create table(:job_aptitude_attempts) do
      add :token, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :invitation_email, :string, null: false
      add :sent_at, :utc_datetime
      add :started_at, :utc_datetime
      add :submitted_at, :utc_datetime
      add :reviewed_at, :utc_datetime
      add :score, :float
      add :max_score, :float
      add :percentage, :integer
      add :summary, :text
      add :recommendation, :text
      add :report_markdown, :text

      add :assessment_id, references(:job_aptitude_assessments, on_delete: :delete_all),
        null: false

      add :job_listing_id, references(:job_listings, on_delete: :delete_all), null: false
      add :application_id, references(:applications, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:job_aptitude_attempts, [:token])
    create unique_index(:job_aptitude_attempts, [:assessment_id, :application_id])
    create index(:job_aptitude_attempts, [:job_listing_id])
    create index(:job_aptitude_attempts, [:status])

    create table(:job_aptitude_answers) do
      add :question_id, :string, null: false
      add :question_position, :integer
      add :question_type, :string, null: false
      add :skill, :string
      add :prompt, :text, null: false
      add :weight, :integer, null: false, default: 1
      add :answer_text, :text
      add :selected_option_id, :string
      add :score, :float
      add :max_score, :float
      add :percentage, :integer
      add :metadata, :map, null: false, default: %{}
      add :attempt_id, references(:job_aptitude_attempts, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:job_aptitude_answers, [:attempt_id, :question_id])
    create index(:job_aptitude_answers, [:attempt_id])

    create table(:job_aptitude_screenshots) do
      add :question_id, :string
      add :image_url, :string, null: false
      add :original_filename, :string
      add :attempt_id, references(:job_aptitude_attempts, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:job_aptitude_screenshots, [:attempt_id])
  end
end
