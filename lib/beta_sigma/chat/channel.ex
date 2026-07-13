defmodule BetaSigma.Chat.Channel do
  use Ecto.Schema
  import Ecto.Changeset

  alias BetaSigma.Accounts.User
  alias BetaSigma.Chat.{ChannelMembership, Message}

  @kind_values [:public, :private, :system]

  schema "chat_channels" do
    field :name, :string
    field :slug, :string
    field :kind, Ecto.Enum, values: @kind_values, default: :public
    field :topic, :string
    field :description, :string
    field :archived_at, :utc_datetime
    field :unread_count, :integer, virtual: true, default: 0

    belongs_to :created_by, User
    has_many :memberships, ChannelMembership
    has_many :members, through: [:memberships, :user]
    has_many :messages, Message

    timestamps(type: :utc_datetime)
  end

  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:name, :slug, :kind, :topic, :description, :created_by_id, :archived_at])
    |> validate_required([:name, :kind])
    |> maybe_generate_slug()
    |> validate_length(:name, min: 1, max: 80)
    |> validate_length(:topic, max: 250)
    |> unique_constraint(:slug)
  end

  def kind_values, do: @kind_values

  defp maybe_generate_slug(changeset) do
    case get_change(changeset, :name) do
      nil ->
        changeset

      name ->
        slug =
          name
          |> String.downcase()
          |> String.replace(~r/[^a-z0-9]+/, "-")
          |> String.trim("-")

        put_change(changeset, :slug, slug)
    end
  end
end
