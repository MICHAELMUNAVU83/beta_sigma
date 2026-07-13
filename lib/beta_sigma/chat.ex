# credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
# credo:disable-for-this-file Credo.Check.Refactor.Nesting
defmodule BetaSigma.Chat do
  @moduledoc false

  import Ecto.Query, warn: false

  alias Phoenix.PubSub
  alias BetaSigma.Accounts

  alias BetaSigma.Chat.{
    Channel,
    ChannelMembership,
    Conversation,
    ConversationMembership,
    Mention,
    Message,
    Reaction
  }

  alias BetaSigma.{EmailTemplate, Mailer, Notifications, Repo}

  # ---------------------------------------------------------------------------
  # PubSub
  # ---------------------------------------------------------------------------

  def subscribe_channel(channel_id) do
    PubSub.subscribe(BetaSigma.PubSub, channel_topic(channel_id))
  end

  def subscribe_conversation(conversation_id) do
    PubSub.subscribe(BetaSigma.PubSub, conversation_topic(conversation_id))
  end

  def subscribe_user(user_id) do
    PubSub.subscribe(BetaSigma.PubSub, user_topic(user_id))
  end

  def subscribe_topic(topic) when is_binary(topic) do
    PubSub.subscribe(BetaSigma.PubSub, topic)
  end

  def unsubscribe_topic(topic) when is_binary(topic) do
    PubSub.unsubscribe(BetaSigma.PubSub, topic)
  end

  def channel_presence_topic(channel_id), do: channel_topic(channel_id)
  def conversation_presence_topic(conversation_id), do: conversation_topic(conversation_id)

  defp channel_topic(id), do: "chat:channel:#{id}"
  defp conversation_topic(id), do: "chat:dm:#{id}"
  defp user_topic(id), do: "chat:user:#{id}"

  defp broadcast_channel(channel_id, event) do
    PubSub.broadcast(BetaSigma.PubSub, channel_topic(channel_id), event)
  end

  defp broadcast_conversation(conversation_id, event) do
    PubSub.broadcast(BetaSigma.PubSub, conversation_topic(conversation_id), event)
  end

  def broadcast_channel_typing(channel_id, payload) do
    broadcast_channel(channel_id, Map.put(payload, :event, :typing))
  end

  def broadcast_conversation_typing(conversation_id, payload) do
    broadcast_conversation(conversation_id, Map.put(payload, :event, :typing))
  end

  defp broadcast_user(user_id, event) do
    PubSub.broadcast(BetaSigma.PubSub, user_topic(user_id), event)
  end

  # ---------------------------------------------------------------------------
  # Channels
  # ---------------------------------------------------------------------------

  def list_channels(opts \\ []) do
    Channel
    |> maybe_filter_kind(opts[:kind])
    |> maybe_exclude_archived(opts[:include_archived])
    |> order_by([c], asc: c.name)
    |> Repo.all()
  end

  def list_channels_for_user(user_id, opts \\ []) do
    from(c in Channel,
      join: m in ChannelMembership,
      on: m.channel_id == c.id and m.user_id == ^user_id,
      left_join: msg in Message,
      on:
        msg.channel_id == c.id and msg.user_id != ^user_id and is_nil(msg.deleted_at) and
          (is_nil(m.last_read_at) or msg.inserted_at > m.last_read_at),
      where: is_nil(c.archived_at),
      group_by: c.id,
      select_merge: %{unread_count: count(msg.id)},
      order_by: [desc: count(msg.id) > 0, asc: c.name]
    )
    |> maybe_filter_kind(opts[:kind])
    |> Repo.all()
  end

  def get_channel!(id), do: Repo.get!(Channel, id)

  def get_channel_by_slug(slug) do
    Repo.get_by(Channel, slug: slug)
  end

  def create_channel(user, attrs, member_ids \\ []) do
    result =
      Repo.transaction(fn ->
        case %Channel{}
             |> Channel.changeset(Map.put(attrs, "created_by_id", user.id))
             |> Repo.insert() do
          {:ok, channel} ->
            add_member(channel, user, :owner)

            Enum.each(member_ids, fn user_id ->
              %ChannelMembership{}
              |> ChannelMembership.changeset(%{
                channel_id: channel.id,
                user_id: user_id,
                role: :member
              })
              |> Repo.insert(on_conflict: :nothing)
            end)

            channel

          {:error, changeset} ->
            Repo.rollback(changeset)
        end
      end)

    case result do
      {:ok, channel} -> {:ok, channel}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def update_channel(%Channel{} = channel, attrs) do
    channel
    |> Channel.changeset(attrs)
    |> Repo.update()
  end

  def archive_channel(%Channel{} = channel) do
    channel
    |> Ecto.Changeset.change(archived_at: DateTime.utc_now() |> DateTime.truncate(:second))
    |> Repo.update()
  end

  def delete_channel(%Channel{} = channel) do
    Repo.delete(channel)
  end

  def change_channel(%Channel{} = channel, attrs \\ %{}) do
    Channel.changeset(channel, attrs)
  end

  # ---------------------------------------------------------------------------
  # Channel memberships
  # ---------------------------------------------------------------------------

  def add_member(%Channel{} = channel, user, role \\ :member) do
    %ChannelMembership{}
    |> ChannelMembership.changeset(%{channel_id: channel.id, user_id: user.id, role: role})
    |> Repo.insert(on_conflict: :nothing)
  end

  def remove_member(%Channel{} = channel, user) do
    case Repo.get_by(ChannelMembership, channel_id: channel.id, user_id: user.id) do
      nil -> {:ok, nil}
      membership -> Repo.delete(membership)
    end
  end

  def member?(%Channel{} = channel, user_id) do
    Repo.exists?(
      from(m in ChannelMembership,
        where: m.channel_id == ^channel.id and m.user_id == ^user_id
      )
    )
  end

  def list_channel_members(%Channel{} = channel) do
    from(u in Accounts.User,
      join: m in ChannelMembership,
      on: m.user_id == u.id and m.channel_id == ^channel.id,
      order_by: [asc: u.name, asc: u.email]
    )
    |> Repo.all()
  end

  def mark_channel_read(%Channel{} = channel, user_id) do
    mark_channel_read(channel.id, user_id)
  end

  def mark_channel_read(channel_id, user_id) when is_integer(channel_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(m in ChannelMembership,
      where: m.channel_id == ^channel_id and m.user_id == ^user_id
    )
    |> Repo.update_all(set: [last_read_at: now])
  end

  # ---------------------------------------------------------------------------
  # Conversations (DMs)
  # ---------------------------------------------------------------------------

  def find_or_create_dm(user_a_id, user_b_id) do
    case find_dm_between(user_a_id, user_b_id) do
      nil -> create_dm(user_a_id, user_b_id)
      conversation -> {:ok, conversation}
    end
  end

  def list_conversations_for_user(user_id) do
    from(c in Conversation,
      join: m in ConversationMembership,
      on: m.conversation_id == c.id and m.user_id == ^user_id,
      left_join: msg in Message,
      on:
        msg.conversation_id == c.id and msg.user_id != ^user_id and is_nil(msg.deleted_at) and
          (is_nil(m.last_read_at) or msg.inserted_at > m.last_read_at),
      group_by: c.id,
      select_merge: %{unread_count: count(msg.id)},
      preload: [memberships: :user],
      order_by: [desc: count(msg.id) > 0, desc: max(msg.inserted_at), desc: c.inserted_at]
    )
    |> Repo.all()
  end

  def get_conversation!(id) do
    Conversation
    |> preload(memberships: :user)
    |> Repo.get!(id)
  end

  def conversation_member?(conversation_id, user_id) do
    Repo.exists?(
      from(m in ConversationMembership,
        where: m.conversation_id == ^conversation_id and m.user_id == ^user_id
      )
    )
  end

  def mark_conversation_read(conversation_id, user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(m in ConversationMembership,
      where: m.conversation_id == ^conversation_id and m.user_id == ^user_id
    )
    |> Repo.update_all(set: [last_read_at: now])
  end

  # ---------------------------------------------------------------------------
  # Messages
  # ---------------------------------------------------------------------------

  def list_channel_messages(channel_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    before = Keyword.get(opts, :before)

    Message
    |> where([m], m.channel_id == ^channel_id and is_nil(m.deleted_at))
    |> maybe_before(before)
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> preload_message_associations()
    |> Repo.all()
    |> Enum.reverse()
  end

  def list_conversation_messages(conversation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    before = Keyword.get(opts, :before)

    Message
    |> where([m], m.conversation_id == ^conversation_id and is_nil(m.deleted_at))
    |> maybe_before(before)
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> preload_message_associations()
    |> Repo.all()
    |> Enum.reverse()
  end

  def send_channel_message(channel_id, user, body, opts \\ []) do
    attachments = Keyword.get(opts, :attachments, [])
    attrs = %{body: body, user_id: user.id, channel_id: channel_id, attachments: attachments}

    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, message} ->
        message = preload_message(message)
        mark_channel_read(channel_id, user.id)

        after_message_send(fn ->
          process_mentions(message, body)
          broadcast_channel(channel_id, %{event: :message_created, message: message})
          broadcast_to_channel_members(channel_id, user.id, %{event: :chat_new_message})
        end)

        {:ok, message}

      error ->
        error
    end
  end

  def send_conversation_message(conversation_id, user, body, opts \\ []) do
    attachments = Keyword.get(opts, :attachments, [])

    attrs = %{
      body: body,
      user_id: user.id,
      conversation_id: conversation_id,
      attachments: attachments
    }

    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, message} ->
        message = preload_message(message)
        mark_conversation_read(conversation_id, user.id)

        after_message_send(fn ->
          process_mentions(message, body)
          broadcast_conversation(conversation_id, %{event: :message_created, message: message})
          broadcast_to_conversation_members(conversation_id, user.id, %{event: :chat_new_message})
        end)

        {:ok, message}

      error ->
        error
    end
  end

  def edit_message(%Message{} = message, user_id, body) do
    if message.user_id == user_id do
      message
      |> Message.edit_changeset(%{body: body})
      |> Repo.update()
      |> case do
        {:ok, updated} ->
          updated = preload_message(updated)
          broadcast_message_update(updated)
          {:ok, updated}

        error ->
          error
      end
    else
      {:error, :unauthorized}
    end
  end

  def delete_message(%Message{} = message, actor_id, actor_role) do
    is_owner = message.user_id == actor_id
    is_admin = actor_role == :admin

    if is_owner or is_admin do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      message
      |> Ecto.Changeset.change(deleted_at: now)
      |> Repo.update()
      |> case do
        {:ok, updated} ->
          updated = preload_message(updated)
          broadcast_message_update(updated)
          {:ok, updated}

        error ->
          error
      end
    else
      {:error, :unauthorized}
    end
  end

  def get_message!(id), do: Repo.get!(Message, id)

  def change_message(%Message{} = message \\ %Message{}, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end

  def allowed_reaction_emojis, do: Reaction.allowed_emojis()

  def toggle_reaction(message_id, user_id, emoji) do
    with true <- emoji in allowed_reaction_emojis(),
         %Message{} = message <- Repo.get(Message, message_id),
         true <- can_access_message?(message, user_id) do
      existing =
        Repo.get_by(Reaction, message_id: message_id, user_id: user_id, emoji: emoji)

      result =
        case existing do
          nil ->
            %Reaction{}
            |> Reaction.changeset(%{message_id: message_id, user_id: user_id, emoji: emoji})
            |> Repo.insert()

          reaction ->
            Repo.delete(reaction)
        end

      case result do
        {:ok, _reaction} ->
          message = preload_message(message)
          broadcast_message_update(message)
          {:ok, message}

        error ->
          error
      end
    else
      false -> {:error, :invalid_emoji}
      nil -> {:error, :not_found}
      :unauthorized -> {:error, :unauthorized}
    end
  end

  def toggle_pin(message_id, user_id) do
    with %Message{} = message <- Repo.get(Message, message_id),
         true <- can_access_message?(message, user_id) do
      change =
        if message.pinned_at do
          %{pinned_at: nil, pinned_by_id: nil}
        else
          %{pinned_at: DateTime.utc_now() |> DateTime.truncate(:second), pinned_by_id: user_id}
        end

      message
      |> Ecto.Changeset.change(change)
      |> Repo.update()
      |> case do
        {:ok, updated} ->
          updated = preload_message(updated)
          broadcast_message_update(updated)
          {:ok, updated}

        error ->
          error
      end
    else
      :unauthorized -> {:error, :unauthorized}
      nil -> {:error, :not_found}
    end
  end

  def list_pinned_channel_messages(channel_id) do
    Message
    |> where(
      [m],
      m.channel_id == ^channel_id and not is_nil(m.pinned_at) and is_nil(m.deleted_at)
    )
    |> order_by([m], desc: m.pinned_at)
    |> preload_message_associations()
    |> Repo.all()
  end

  def list_pinned_conversation_messages(conversation_id) do
    Message
    |> where(
      [m],
      m.conversation_id == ^conversation_id and not is_nil(m.pinned_at) and is_nil(m.deleted_at)
    )
    |> order_by([m], desc: m.pinned_at)
    |> preload_message_associations()
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # Search
  # ---------------------------------------------------------------------------

  def search_messages(query, user_id, opts \\ [])

  def search_messages(query, user_id, opts) when is_binary(query) and byte_size(query) > 0 do
    limit = Keyword.get(opts, :limit, 30)
    like = "%#{query}%"

    from(m in Message,
      left_join: cm in ChannelMembership,
      on: cm.channel_id == m.channel_id and cm.user_id == ^user_id,
      left_join: dm in ConversationMembership,
      on: dm.conversation_id == m.conversation_id and dm.user_id == ^user_id,
      where:
        ilike(m.body, ^like) and
          is_nil(m.deleted_at) and
          (not is_nil(cm.id) or not is_nil(dm.id)),
      order_by: [desc: m.inserted_at],
      limit: ^limit,
      preload: [:user, :channel, :conversation]
    )
    |> Repo.all()
  end

  def search_messages(_query, _user_id, _opts), do: []

  # ---------------------------------------------------------------------------
  # Unread counts
  # ---------------------------------------------------------------------------

  def unread_channel_count(channel_id, user_id) do
    membership = Repo.get_by(ChannelMembership, channel_id: channel_id, user_id: user_id)

    case membership do
      nil ->
        0

      %{last_read_at: nil} ->
        Repo.aggregate(
          from(m in Message,
            where:
              m.channel_id == ^channel_id and is_nil(m.deleted_at) and
                m.user_id != ^user_id
          ),
          :count
        )

      %{last_read_at: last_read_at} ->
        Repo.aggregate(
          from(m in Message,
            where:
              m.channel_id == ^channel_id and is_nil(m.deleted_at) and
                m.user_id != ^user_id and
                m.inserted_at > ^last_read_at
          ),
          :count
        )
    end
  end

  def unread_mention_count(user_id) do
    Repo.aggregate(
      from(mn in Mention, where: mn.mentioned_user_id == ^user_id and is_nil(mn.read_at)),
      :count
    )
  end

  def total_channel_unread_count(user_id) do
    from(m in ChannelMembership,
      left_join: msg in Message,
      on:
        msg.channel_id == m.channel_id and msg.user_id != ^user_id and is_nil(msg.deleted_at) and
          (is_nil(m.last_read_at) or msg.inserted_at > m.last_read_at),
      where: m.user_id == ^user_id,
      select: count(msg.id)
    )
    |> Repo.one() || 0
  end

  def total_dm_unread_count(user_id) do
    from(m in ConversationMembership,
      left_join: msg in Message,
      on:
        msg.conversation_id == m.conversation_id and msg.user_id != ^user_id and
          is_nil(msg.deleted_at) and
          (is_nil(m.last_read_at) or msg.inserted_at > m.last_read_at),
      where: m.user_id == ^user_id,
      select: count(msg.id)
    )
    |> Repo.one() || 0
  end

  def total_chat_unread_count(user_id) do
    total_channel_unread_count(user_id) + total_dm_unread_count(user_id)
  end

  def unread_conversation_count(conversation_id, user_id) do
    membership =
      Repo.get_by(ConversationMembership, conversation_id: conversation_id, user_id: user_id)

    case membership do
      nil ->
        0

      %{last_read_at: nil} ->
        Repo.aggregate(
          from(m in Message,
            where:
              m.conversation_id == ^conversation_id and is_nil(m.deleted_at) and
                m.user_id != ^user_id
          ),
          :count
        )

      %{last_read_at: last_read_at} ->
        Repo.aggregate(
          from(m in Message,
            where:
              m.conversation_id == ^conversation_id and is_nil(m.deleted_at) and
                m.user_id != ^user_id and
                m.inserted_at > ^last_read_at
          ),
          :count
        )
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp find_dm_between(user_a_id, user_b_id) do
    from(c in Conversation,
      join: m1 in ConversationMembership,
      on: m1.conversation_id == c.id and m1.user_id == ^user_a_id,
      join: m2 in ConversationMembership,
      on: m2.conversation_id == c.id and m2.user_id == ^user_b_id,
      where: c.kind == :dm
    )
    |> Repo.one()
  end

  defp create_dm(user_a_id, user_b_id) do
    Repo.transaction(fn ->
      {:ok, conversation} =
        %Conversation{}
        |> Conversation.changeset(%{kind: :dm, created_by_id: user_a_id})
        |> Repo.insert()

      Repo.insert!(%ConversationMembership{conversation_id: conversation.id, user_id: user_a_id})
      Repo.insert!(%ConversationMembership{conversation_id: conversation.id, user_id: user_b_id})

      conversation
    end)
  end

  defp process_mentions(%Message{} = message, body) do
    user_ids = mentioned_user_ids(message, body)

    if user_ids != [] do
      users = Repo.all(from(u in Accounts.User, where: u.id in ^user_ids))
      sender_name = message.user.name || message.user.email
      link = mention_link(message)

      Enum.each(users, fn user ->
        case %Mention{}
             |> Mention.changeset(%{message_id: message.id, mentioned_user_id: user.id})
             |> Repo.insert(on_conflict: :nothing) do
          {:ok, _} ->
            broadcast_user(user.id, %{event: :chat_mention, message: message})

            Notifications.create_notification(
              user.id,
              "chat_mention",
              chat_mention_message(sender_name, body),
              link
            )

            send_mention_email(user, sender_name, message, link)

          _ ->
            :ok
        end
      end)
    end
  end

  defp mentioned_user_ids(%Message{} = message, body) do
    direct_mention_user_ids =
      Regex.scan(~r/@\[([^\]]+)\]\(user:(\d+)\)/, body, capture: :all_but_first)
      |> Enum.map(fn [_name, id] -> String.to_integer(id) end)

    all_mention_user_ids = all_mention_user_ids(message, body)

    (direct_mention_user_ids ++ all_mention_user_ids)
    |> Enum.uniq()
    |> Enum.reject(&(&1 == message.user_id))
  end

  defp all_mention_user_ids(%Message{channel_id: channel_id}, body)
       when not is_nil(channel_id) and is_binary(body) do
    if all_mention?(body) do
      channel = Repo.get!(Channel, channel_id)
      all_mention_user_ids_for_channel(channel)
    else
      []
    end
  end

  defp all_mention_user_ids(_message, _body), do: []

  defp all_mention_user_ids_for_channel(%Channel{kind: :public}) do
    Repo.all(from(u in Accounts.User, select: u.id))
  end

  defp all_mention_user_ids_for_channel(%Channel{id: channel_id}) do
    Repo.all(from(m in ChannelMembership, where: m.channel_id == ^channel_id, select: m.user_id))
  end

  defp all_mention?(body), do: Regex.match?(~r/(^|[^\w])@all\b/i, body)

  defp chat_mention_message(sender_name, body) do
    if is_binary(body) and all_mention?(body) do
      "#{sender_name} mentioned everyone in a channel message"
    else
      "#{sender_name} mentioned you in a message"
    end
  end

  defp mention_link(%Message{channel_id: channel_id}) when not is_nil(channel_id),
    do: "/app/chat?channel=#{channel_id}"

  defp mention_link(%Message{conversation_id: conv_id}) when not is_nil(conv_id),
    do: "/app/chat?dm=#{conv_id}"

  defp mention_link(_), do: "/app/chat"

  defp send_mention_email(user, sender_name, message, link) do
    base_url = "https://vumbuzi-ai.com/"
    full_link = base_url <> link

    recipient_name = user.name || user.email

    msg = %{
      eyebrow: "Chat mention",
      preheader: "#{sender_name} mentioned you in a message.",
      title: "#{sender_name} mentioned you",
      intro: "Hi #{recipient_name}, #{sender_name} mentioned you in a message:",
      details: [{"Message", message_context(message.body)}],
      cta: %{label: "View message →", url: full_link},
      footer_note: "This mention notification was sent by BetaSigma.",
      sign_off: false
    }

    Mailer.deliver(%{
      to: user.email,
      subject: "#{sender_name} mentioned you in a message",
      html_body: EmailTemplate.render_html(msg),
      text_body: EmailTemplate.render_text(msg)
    })
  end

  defp message_context(body) when is_binary(body) and body != "" do
    body
    |> String.replace(~r/@\[([^\]]+)\]\(user:\d+\)/, "@\\1")
  end

  defp message_context(_), do: "(no text — see attachments)"

  defp after_message_send(fun) when is_function(fun, 0) do
    case Application.get_env(:beta_sigma, :chat_side_effects, :async) do
      :sync ->
        fun.()

      _ ->
        Task.Supervisor.start_child(BetaSigma.TaskSupervisor, fun)
        :ok
    end
  end

  defp maybe_filter_kind(query, nil), do: query
  defp maybe_filter_kind(query, kind), do: where(query, [c], c.kind == ^kind)

  defp maybe_exclude_archived(query, true), do: query
  defp maybe_exclude_archived(query, _), do: where(query, [c], is_nil(c.archived_at))

  defp maybe_before(query, nil), do: query

  defp maybe_before(query, %DateTime{} = dt),
    do: where(query, [m], m.inserted_at < ^dt)

  defp can_access_message?(%Message{channel_id: channel_id}, user_id)
       when not is_nil(channel_id) do
    channel = Repo.get(Channel, channel_id)

    cond do
      is_nil(channel) -> :unauthorized
      channel.kind == :public -> true
      member?(channel, user_id) -> true
      true -> :unauthorized
    end
  end

  defp can_access_message?(%Message{conversation_id: conversation_id}, user_id)
       when not is_nil(conversation_id) do
    if conversation_member?(conversation_id, user_id), do: true, else: :unauthorized
  end

  defp can_access_message?(_message, _user_id), do: :unauthorized

  defp preload_message(%Message{} = message),
    do: Repo.preload(message, [:user, :pinned_by, reactions: :user])

  defp preload_message_associations(query),
    do: preload(query, [:user, :pinned_by, reactions: :user])

  defp broadcast_to_channel_members(channel_id, sender_id, event) do
    member_ids =
      Repo.all(
        from(m in ChannelMembership, where: m.channel_id == ^channel_id, select: m.user_id)
      )

    Enum.each(member_ids, fn user_id ->
      if user_id != sender_id, do: broadcast_user(user_id, event)
    end)
  end

  defp broadcast_to_conversation_members(conversation_id, sender_id, event) do
    member_ids =
      Repo.all(
        from(m in ConversationMembership,
          where: m.conversation_id == ^conversation_id,
          select: m.user_id
        )
      )

    Enum.each(member_ids, fn user_id ->
      if user_id != sender_id, do: broadcast_user(user_id, event)
    end)
  end

  defp broadcast_message_update(%Message{channel_id: channel_id} = msg)
       when not is_nil(channel_id) do
    broadcast_channel(channel_id, %{event: :message_updated, message: msg})
  end

  defp broadcast_message_update(%Message{conversation_id: conv_id} = msg)
       when not is_nil(conv_id) do
    broadcast_conversation(conv_id, %{event: :message_updated, message: msg})
  end

  defp broadcast_message_update(_), do: :ok
end
