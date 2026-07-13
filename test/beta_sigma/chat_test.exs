defmodule BetaSigma.ChatTest do
  use BetaSigma.DataCase, async: true

  import BetaSigma.AccountsFixtures

  alias BetaSigma.Chat
  alias BetaSigma.Chat.Mention
  alias BetaSigma.{Notifications, Repo}

  describe "messages" do
    test "messages can include emoji text" do
      user = user_fixture()
      {:ok, channel} = Chat.create_channel(user, %{"name" => "General", "kind" => "public"})

      assert {:ok, message} = Chat.send_channel_message(channel.id, user, "Launch day 🎉")
      assert message.body == "Launch day 🎉"

      assert [%{body: "Launch day 🎉"}] = Chat.list_channel_messages(channel.id)
    end
  end

  describe "message mentions" do
    test "@all in a public channel message notifies every other user" do
      sender = user_fixture()
      teammate = user_fixture()
      another_teammate = user_fixture()
      outsider = user_fixture()

      {:ok, channel} =
        Chat.create_channel(
          sender,
          %{"name" => "General", "kind" => "public"},
          [teammate.id, another_teammate.id]
        )

      assert {:ok, message} =
               Chat.send_channel_message(
                 channel.id,
                 sender,
                 "@all please review the release plan"
               )

      assert [teammate_notification] = Notifications.list_notifications(teammate.id)
      assert teammate_notification.type == "chat_mention"
      assert teammate_notification.message =~ "mentioned everyone in a channel message"
      assert teammate_notification.link == "/app/chat?channel=#{channel.id}"

      assert [another_notification] = Notifications.list_notifications(another_teammate.id)
      assert another_notification.type == "chat_mention"
      assert another_notification.message =~ "mentioned everyone in a channel message"

      assert Notifications.list_notifications(sender.id) == []
      assert [outsider_notification] = Notifications.list_notifications(outsider.id)
      assert outsider_notification.type == "chat_mention"
      assert outsider_notification.message =~ "mentioned everyone in a channel message"

      mentioned_user_ids =
        Mention
        |> Repo.all()
        |> Enum.filter(&(&1.message_id == message.id))
        |> Enum.map(& &1.mentioned_user_id)
        |> Enum.sort()

      assert mentioned_user_ids == Enum.sort([teammate.id, another_teammate.id, outsider.id])
    end

    test "@all in a private channel message only notifies channel members" do
      sender = user_fixture()
      teammate = user_fixture()
      outsider = user_fixture()

      {:ok, channel} =
        Chat.create_channel(
          sender,
          %{"name" => "Leadership", "kind" => "private"},
          [teammate.id]
        )

      assert {:ok, message} =
               Chat.send_channel_message(channel.id, sender, "@all please review this privately")

      assert [_teammate_notification] = Notifications.list_notifications(teammate.id)
      assert Notifications.list_notifications(sender.id) == []
      assert Notifications.list_notifications(outsider.id) == []

      mentioned_user_ids =
        Mention
        |> Repo.all()
        |> Enum.filter(&(&1.message_id == message.id))
        |> Enum.map(& &1.mentioned_user_id)
        |> Enum.sort()

      assert mentioned_user_ids == [teammate.id]
    end

    test "@all in a direct message does not notify everyone" do
      sender = user_fixture()
      recipient = user_fixture()

      {:ok, conversation} = Chat.find_or_create_dm(sender.id, recipient.id)

      assert {:ok, _message} =
               Chat.send_conversation_message(conversation.id, sender, "@all please review this")

      assert Notifications.list_notifications(sender.id) == []
      assert Notifications.list_notifications(recipient.id) == []
      assert Repo.aggregate(Mention, :count) == 0
    end
  end

  describe "message reactions" do
    test "users can toggle emoji reactions on messages" do
      sender = user_fixture()
      reactor = user_fixture()

      {:ok, channel} =
        Chat.create_channel(sender, %{"name" => "General", "kind" => "public"}, [reactor.id])

      {:ok, message} = Chat.send_channel_message(channel.id, sender, "Hello team")

      assert {:ok, reacted_message} = Chat.toggle_reaction(message.id, reactor.id, "👍")
      assert [%{emoji: "👍", user_id: user_id}] = reacted_message.reactions
      assert user_id == reactor.id

      assert {:ok, unreacted_message} = Chat.toggle_reaction(message.id, reactor.id, "👍")
      assert unreacted_message.reactions == []
    end

    test "rejects unsupported emoji reactions" do
      user = user_fixture()
      {:ok, channel} = Chat.create_channel(user, %{"name" => "General", "kind" => "public"})
      {:ok, message} = Chat.send_channel_message(channel.id, user, "Hello team")

      assert {:error, :invalid_emoji} = Chat.toggle_reaction(message.id, user.id, "🔥")
    end
  end

  describe "channel unread counts" do
    test "sent messages are not unread for the sender" do
      sender = user_fixture()
      recipient = user_fixture()

      {:ok, channel} =
        Chat.create_channel(sender, %{"name" => "General", "kind" => "public"}, [recipient.id])

      {:ok, _message} = Chat.send_channel_message(channel.id, sender, "Hello team")

      assert Chat.unread_channel_count(channel.id, sender.id) == 0
      assert Chat.unread_channel_count(channel.id, recipient.id) == 1
      assert Chat.total_channel_unread_count(sender.id) == 0
      assert Chat.total_channel_unread_count(recipient.id) == 1

      sender_channel = Enum.find(Chat.list_channels_for_user(sender.id), &(&1.id == channel.id))

      recipient_channel =
        Enum.find(Chat.list_channels_for_user(recipient.id), &(&1.id == channel.id))

      assert sender_channel.unread_count == 0
      assert recipient_channel.unread_count == 1
    end
  end

  describe "DM unread counts" do
    test "sent messages are not unread for the sender" do
      sender = user_fixture()
      recipient = user_fixture()

      {:ok, conversation} = Chat.find_or_create_dm(sender.id, recipient.id)
      {:ok, _message} = Chat.send_conversation_message(conversation.id, sender, "Hello")

      assert Chat.unread_conversation_count(conversation.id, sender.id) == 0
      assert Chat.unread_conversation_count(conversation.id, recipient.id) == 1
      assert Chat.total_dm_unread_count(sender.id) == 0
      assert Chat.total_dm_unread_count(recipient.id) == 1

      sender_conversation =
        Enum.find(Chat.list_conversations_for_user(sender.id), &(&1.id == conversation.id))

      recipient_conversation =
        Enum.find(Chat.list_conversations_for_user(recipient.id), &(&1.id == conversation.id))

      assert sender_conversation.unread_count == 0
      assert recipient_conversation.unread_count == 1
    end
  end
end
