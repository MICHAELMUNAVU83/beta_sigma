defmodule BetaSigma.Repo.Migrations.RefactorBlogPostsForDynamicContent do
  use Ecto.Migration

  def up do
    alter table(:blog_posts) do
      add :excerpt, :text
      add :status, :string, null: false, default: "published"
      add :hero_title, :string
      add :hero_subtitle, :text
      add :hero_image_url, :string
      add :published_at, :utc_datetime
      add :meta_title, :string
      add :meta_description, :text
    end

    create table(:blog_post_blocks) do
      add :blog_post_id, references(:blog_posts, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :position, :integer, null: false
      add :visible, :boolean, null: false, default: true
      add :data, :map, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:blog_post_blocks, [:blog_post_id])
    create unique_index(:blog_post_blocks, [:blog_post_id, :position])
    create index(:blog_posts, [:status])
    create index(:blog_posts, [:published_at])

    execute("""
    UPDATE blog_posts
    SET excerpt = LEFT(content, 240),
        hero_title = title,
        hero_subtitle = LEFT(content, 260),
        hero_image_url = image_url,
        published_at = inserted_at,
        meta_title = title,
        meta_description = LEFT(content, 160)
    """)

    execute("""
    INSERT INTO blog_post_blocks (blog_post_id, type, position, visible, data, inserted_at, updated_at)
    SELECT id,
           'rich_text_section',
           0,
           TRUE,
           jsonb_build_object('heading', title, 'body', content),
           NOW(),
           NOW()
    FROM blog_posts
    WHERE COALESCE(content, '') <> ''
    """)

    alter table(:blog_posts) do
      remove :content
      remove :image_url
    end
  end

  def down do
    alter table(:blog_posts) do
      add :content, :text
      add :image_url, :string
    end

    execute("""
    UPDATE blog_posts
    SET content = COALESCE(excerpt, hero_subtitle, title),
        image_url = hero_image_url
    """)

    execute("""
    UPDATE blog_posts AS posts
    SET content = source.body
    FROM (
      SELECT DISTINCT ON (blog_post_id)
             blog_post_id,
             data ->> 'body' AS body
      FROM blog_post_blocks
      WHERE type = 'rich_text_section'
      ORDER BY blog_post_id, position ASC
    ) AS source
    WHERE posts.id = source.blog_post_id
      AND COALESCE(source.body, '') <> ''
    """)

    drop_if_exists index(:blog_post_blocks, [:blog_post_id, :position])
    drop_if_exists index(:blog_post_blocks, [:blog_post_id])
    drop_if_exists index(:blog_posts, [:status])
    drop_if_exists index(:blog_posts, [:published_at])
    drop table(:blog_post_blocks)

    alter table(:blog_posts) do
      remove :excerpt
      remove :status
      remove :hero_title
      remove :hero_subtitle
      remove :hero_image_url
      remove :published_at
      remove :meta_title
      remove :meta_description
    end
  end
end
