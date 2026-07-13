defmodule BetaSigma.Repo.Migrations.AddAptitudeInviteTrackingToAttempts do
  use Ecto.Migration

  def change do
    alter table(:job_aptitude_attempts) do
      add :invite_delivery_status, :string, null: false, default: "pending"
      add :invite_queued_at, :utc_datetime
      add :invite_sender_email, :string
      add :invite_sender_name, :string
      add :invite_last_error, :text
      add :invite_delivery_attempts, :integer, null: false, default: 0
    end

    create index(:job_aptitude_attempts, [:invite_delivery_status])
  end
end
