defmodule BetaSigma.Repo.Migrations.CreateMailboxesAndMessages do
  use Ecto.Migration

  def change do
    create table(:mailboxes) do
      add :address, :string, null: false
      add :local_part, :string, null: false
      add :domain, :string, null: false
      add :display_name, :string
      add :active, :boolean, null: false, default: true
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:mailboxes, [:address])
    create index(:mailboxes, [:user_id])
    create index(:mailboxes, [:domain])

    create table(:messages) do
      add :direction, :string, null: false
      add :status, :string, null: false
      add :from_address, :string, null: false
      add :to_addresses, {:array, :string}, null: false, default: []
      add :subject, :string
      add :text_body, :text
      add :html_body, :text
      add :message_id, :string
      add :size_bytes, :integer
      add :error, :string
      add :mailbox_id, references(:mailboxes, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:messages, [:mailbox_id])
    create index(:messages, [:direction, :status])
    create index(:messages, [:message_id])
  end
end
