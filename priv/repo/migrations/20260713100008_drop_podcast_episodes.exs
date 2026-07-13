defmodule BetaSigma.Repo.Migrations.DropPodcastEpisodes do
  use Ecto.Migration

  def change do
    drop table(:podcast_episodes)
  end
end
