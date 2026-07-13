defmodule BetaSigma.Repo.Migrations.AddAttachmentsToChatMessages do
  use Ecto.Migration

  def change do
    alter table(:chat_messages) do
      add :attachments, {:array, :map}, default: [], null: false
    end
  end
end
