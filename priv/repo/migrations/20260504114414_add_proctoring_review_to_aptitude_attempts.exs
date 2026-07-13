defmodule BetaSigma.Repo.Migrations.AddProctoringReviewToAptitudeAttempts do
  use Ecto.Migration

  def change do
    alter table(:job_aptitude_attempts) do
      add :proctoring_review_status, :string, null: false, default: "pending"
      add :proctoring_review_concern, :string
      add :proctoring_review_summary, :text
      add :proctoring_review_flags, :map, null: false, default: %{}
      add :proctoring_review_error, :text
      add :proctoring_review_completed_at, :utc_datetime
    end

    create index(:job_aptitude_attempts, [:proctoring_review_status])
  end
end
