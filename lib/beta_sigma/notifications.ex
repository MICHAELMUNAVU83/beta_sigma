defmodule BetaSigma.Notifications do
  @moduledoc """
  The Notifications context.
  """

  import Ecto.Query, warn: false

  alias Phoenix.PubSub
  alias BetaSigma.Notifications.Notification
  alias BetaSigma.Repo

  def subscribe(user_id) do
    PubSub.subscribe(BetaSigma.PubSub, topic(user_id))
  end

  def create_notification(user_id, type, message, link \\ nil) do
    %Notification{}
    |> Notification.changeset(%{user_id: user_id, type: type, message: message, link: link})
    |> Repo.insert()
    |> case do
      {:ok, notification} ->
        broadcast(user_id, %{
          event: :notification_created,
          notification: notification,
          unread_count: unread_count(user_id)
        })

        {:ok, notification}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def list_notifications(user_id, filters \\ []) do
    Notification
    |> where([notification], notification.user_id == ^user_id)
    |> maybe_filter_notification_read(filters[:read])
    |> maybe_filter_notification_type(filters[:type])
    |> order_by([notification], desc: notification.inserted_at)
    |> Repo.all()
  end

  def list_unread_notifications(user_id) do
    list_notifications(user_id, read: false)
  end

  def get_notification!(id), do: Repo.get!(Notification, id)

  def mark_read(%Notification{} = notification) do
    update_notification_read(notification, true, :notification_read)
  end

  def mark_unread(%Notification{} = notification) do
    update_notification_read(notification, false, :notification_unread)
  end

  def mark_all_read(user_id) do
    Notification
    |> where([notification], notification.user_id == ^user_id and notification.read == false)
    |> Repo.update_all(set: [read: true])

    broadcast(user_id, %{event: :notifications_read_all, unread_count: unread_count(user_id)})
    :ok
  end

  def unread_count(user_id) do
    Notification
    |> where([notification], notification.user_id == ^user_id and notification.read == false)
    |> Repo.aggregate(:count)
  end

  def broadcast(user_id, event) do
    PubSub.broadcast(BetaSigma.PubSub, topic(user_id), event)
  end

  defp update_notification_read(notification, read_value, event_name) do
    notification
    |> Notification.changeset(%{read: read_value})
    |> Repo.update()
    |> case do
      {:ok, updated_notification} ->
        broadcast(updated_notification.user_id, %{
          event: event_name,
          notification: updated_notification,
          unread_count: unread_count(updated_notification.user_id)
        })

        {:ok, updated_notification}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp maybe_filter_notification_read(query, nil), do: query

  defp maybe_filter_notification_read(query, read),
    do: from(notification in query, where: notification.read == ^read)

  defp maybe_filter_notification_type(query, nil), do: query

  defp maybe_filter_notification_type(query, type),
    do: from(notification in query, where: notification.type == ^type)

  defp topic(user_id), do: "user:#{user_id}"
end
