defmodule BetaSigma.Repo.Migrations.CreatePodcastEpisodes do
  use Ecto.Migration

  def change do
    create table(:podcast_episodes) do
      add :podcast_name, :string, null: false
      add :episode_title, :string, null: false
      add :guest_name, :string, null: false
      add :guest_company, :string
      add :guest_contact, :string
      add :status, :string, null: false, default: "planning"
      add :booked_on, :date
      add :recording_date, :date
      add :release_date, :date
      add :notes, :text
      add :questions, :text
      add :created_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:podcast_episodes, [:status])
    create index(:podcast_episodes, [:booked_on])
    create index(:podcast_episodes, [:recording_date])
    create index(:podcast_episodes, [:release_date])
    create index(:podcast_episodes, [:created_by_id])
  end
end
