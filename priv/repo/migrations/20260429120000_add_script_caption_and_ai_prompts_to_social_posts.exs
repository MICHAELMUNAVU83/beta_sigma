defmodule BetaSigma.Repo.Migrations.AddScriptCaptionAndAiPromptsToSocialPosts do
  use Ecto.Migration

  def change do
    alter table(:social_media_posts) do
      add :content_script, :text
      add :caption, :text
      add :ai_prompt, :text
      add :ai_media_prompt, :text
    end
  end
end
