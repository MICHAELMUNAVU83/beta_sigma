defmodule BetaSigma.Repo.Migrations.DropBlogTables do
  use Ecto.Migration

  def change do
    drop table(:blog_post_blocks)
    drop table(:blog_posts)
  end
end
