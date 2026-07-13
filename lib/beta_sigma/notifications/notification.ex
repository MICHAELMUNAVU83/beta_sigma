defmodule BetaSigma.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notifications" do
    field :type, :string
    field :message, :string
    field :link, :string
    field :read, :boolean, default: false

    belongs_to :user, BetaSigma.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:type, :message, :link, :read, :user_id])
    |> validate_required([:message, :user_id])
    |> validate_length(:type, max: 100)
    |> validate_length(:message, max: 255)
    |> foreign_key_constraint(:user_id)
  end
end
