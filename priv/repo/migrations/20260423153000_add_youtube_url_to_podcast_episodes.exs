defmodule BetaSigma.Repo.Migrations.AddYoutubeUrlToPodcastEpisodes do
  use Ecto.Migration

  def change do
    alter table(:podcast_episodes) do
      add :youtube_url, :string
    end

    create index(:podcast_episodes, [:youtube_url])
  end
end
