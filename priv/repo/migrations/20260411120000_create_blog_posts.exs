defmodule BetaSigma.Repo.Migrations.CreateBlogPosts do
  use Ecto.Migration

  def change do
    create table(:blog_posts) do
      add :title, :string, null: false
      add :slug, :string, null: false
      add :content, :text, null: false
      add :image_url, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:blog_posts, [:slug])
  end
end
