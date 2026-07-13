defmodule BetaSigma.Repo.Migrations.AddInterviewInviteTrackingToApplications do
  use Ecto.Migration

  def change do
    alter table(:applications) do
      add :interview_invite_sent_at, :utc_datetime
      add :interview_invite_send_count, :integer, null: false, default: 0
    end
  end
end
