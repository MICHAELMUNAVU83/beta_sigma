defmodule BetaSigma.Repo.Migrations.DropInquiries do
  use Ecto.Migration

  def change do
    drop table(:inquiries)
  end
end
