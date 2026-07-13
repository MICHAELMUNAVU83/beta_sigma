defmodule BetaSigma.Repo.Migrations.DropSocialMediaTables do
  use Ecto.Migration

  def change do
    drop table(:social_media_brand_documents)
    drop table(:social_media_brand_contexts)
    drop table(:social_media_posts)
    drop table(:social_media_brands)
    drop table(:social_accounts)
    drop table(:social_media_trend_snapshots)
  end
end
