defmodule BetaSigma.Repo.Migrations.CreateInquiries do
  use Ecto.Migration

  def change do
    create table(:inquiries) do
      add :name, :string, null: false
      add :email, :string, null: false
      add :phone, :string
      add :address, :string
      add :message, :text, null: false
      add :source, :string, null: false, default: "landing_page"

      timestamps(type: :utc_datetime)
    end

    create index(:inquiries, [:source])
    create index(:inquiries, [:inserted_at])
    create index(:inquiries, [:email])
  end
end
