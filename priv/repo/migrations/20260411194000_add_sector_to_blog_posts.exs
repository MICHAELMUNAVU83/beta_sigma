defmodule BetaSigma.Repo.Migrations.AddSectorToBlogPosts do
  use Ecto.Migration

  def up do
    alter table(:blog_posts) do
      add :sector, :string, null: false, default: "General"
    end

    create index(:blog_posts, [:sector])
  end

  def down do
    drop_if_exists index(:blog_posts, [:sector])

    alter table(:blog_posts) do
      remove :sector
    end
  end
end
