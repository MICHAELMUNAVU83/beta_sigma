defmodule BetaSigma.Repo.Migrations.AddPodcastScriptToPodcastEpisodes do
  use Ecto.Migration

  def change do
    alter table(:podcast_episodes) do
      add :podcast_script, :text
      add :guest_company_brief, :text
    end
  end
end
