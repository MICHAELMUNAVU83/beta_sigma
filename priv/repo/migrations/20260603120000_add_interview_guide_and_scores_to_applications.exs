defmodule BetaSigma.Repo.Migrations.AddInterviewGuideAndScoresToApplications do
  use Ecto.Migration

  def change do
    alter table(:applications) do
      add :interview_guide, :map
      add :interview_guide_generated_at, :utc_datetime
      add :interview_scores, :map
      add :interview_score_notes, :text
    end
  end
end
