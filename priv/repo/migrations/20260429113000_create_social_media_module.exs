defmodule BetaSigma.Repo.Migrations.CreateSocialMediaModule do
  use Ecto.Migration

  def change do
    create table(:social_media_brands) do
      add :key, :string, null: false, default: "default"
      add :name, :string, null: false
      add :tone, :text
      add :target_audience, :text
      add :industry, :string
      add :website_url, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:social_media_brands, [:key])

    create table(:social_media_brand_contexts) do
      add :brand_id, references(:social_media_brands, on_delete: :delete_all), null: false
      add :source_url, :string, null: false
      add :fetched_at, :utc_datetime, null: false
      add :description, :text
      add :headings, {:array, :text}, null: false, default: []
      add :keywords, {:array, :text}, null: false, default: []
      add :product_services, {:array, :text}, null: false, default: []
      add :raw_text, :text
      add :metadata, :map

      timestamps(type: :utc_datetime)
    end

    create index(:social_media_brand_contexts, [:brand_id])
    create index(:social_media_brand_contexts, [:fetched_at])

    create table(:social_media_brand_documents) do
      add :brand_id, references(:social_media_brands, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :file_url, :string, null: false
      add :content_type, :string
      add :content_text, :text
      add :metadata, :map

      timestamps(type: :utc_datetime)
    end

    create index(:social_media_brand_documents, [:brand_id])

    create table(:social_media_posts) do
      add :brand_id, references(:social_media_brands, on_delete: :delete_all), null: false
      add :platform, :string, null: false
      add :status, :string, null: false, default: "draft"
      add :content, :text, null: false, default: ""
      add :media, :map
      add :scheduled_at, :utc_datetime
      add :published_at, :utc_datetime
      add :external_post_id, :string
      add :publish_job_id, :bigint
      add :publish_error, :text
      add :ai_metadata, :map

      timestamps(type: :utc_datetime)
    end

    create index(:social_media_posts, [:brand_id])
    create index(:social_media_posts, [:platform])
    create index(:social_media_posts, [:status])
    create index(:social_media_posts, [:scheduled_at])

    create constraint(:social_media_posts, :platform_must_be_valid,
             check: "platform in ('twitter','instagram','linkedin')"
           )

    create constraint(:social_media_posts, :status_must_be_valid,
             check: "status in ('draft','scheduled','published','failed')"
           )

    create table(:social_accounts) do
      add :platform, :string, null: false
      add :account_id, :string
      add :account_name, :string
      add :access_token, :text
      add :refresh_token, :text
      add :expires_at, :utc_datetime
      add :token_type, :string
      add :scopes, {:array, :string}, null: false, default: []
      add :status, :string, null: false, default: "disconnected"
      add :connected_at, :utc_datetime
      add :metadata, :map

      timestamps(type: :utc_datetime)
    end

    create unique_index(:social_accounts, [:platform])

    create constraint(:social_accounts, :platform_must_be_valid,
             check: "platform in ('twitter','instagram','linkedin')"
           )

    create constraint(:social_accounts, :status_must_be_valid,
             check: "status in ('connected','disconnected','error')"
           )

    create table(:social_media_trend_snapshots) do
      add :source, :string, null: false
      add :fetched_at, :utc_datetime, null: false
      add :topics, {:array, :text}, null: false, default: []
      add :payload, :map

      timestamps(type: :utc_datetime)
    end

    create index(:social_media_trend_snapshots, [:source])
    create index(:social_media_trend_snapshots, [:fetched_at])
  end
end
