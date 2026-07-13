defmodule BetaSigma.Repo.Migrations.AddPublicShareTokenToApplications do
  use Ecto.Migration

  def change do
    alter table(:applications) do
      add :public_share_token, :string
    end

    create unique_index(:applications, [:public_share_token])
  end
end
