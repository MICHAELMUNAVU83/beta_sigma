# credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
# credo:disable-for-this-file Credo.Check.Refactor.Nesting
defmodule BetaSigmaWeb.ChatLive.Index do
  use BetaSigmaWeb, :live_view

  alias Phoenix.LiveView.JS
  alias BetaSigma.{Accounts, Chat}
  alias BetaSigma.Chat.Channel
  alias BetaSigmaWeb.Presence
  alias BetaSigmaWeb.Realtime

  @mention_regex ~r/@\[([^\]]+)\]\(user:(\d+)\)/
  @markdown_image_regex ~r/!\[([^\]\n]*)\]\(([^)\s\n]+)\)/
  @url_regex ~r"https?:\/\/[^\s<]+"
  @quick_reaction_emojis Chat.allowed_reaction_emojis()
  @kenya_offset_seconds 3 * 60 * 60

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if connected?(socket) do
      Chat.subscribe_user(user.id)
    end

    # I a testing

    {:ok,
     socket
     |> Realtime.bootstrap()
     |> assign(:page_title, "Chat")
     |> assign(:active_panel, :channels)
     |> assign(:active_channel, nil)
     |> assign(:active_conversation, nil)
     |> assign(:messages, [])
     |> assign(:pinned_messages, [])
     |> assign(:draft, "")
     |> assign(:search_query, "")
     |> assign(:search_results, [])
     |> assign(:active_modal, nil)
     |> assign(:new_dm_query, "")
     |> assign(:new_dm_users, [])
     |> assign(:manage_members_all, [])
     |> assign(:mobile_sidebar_open, true)
     |> assign(:mention_users, load_mention_users())
     |> assign(:code_mode, false)
     |> assign(:presence_topic, nil)
     |> assign(:subscribed_chat_topic, nil)
     |> assign(:online_users, [])
     |> assign(:typing_users, %{})
     |> allow_upload(:chat_media,
       accept:
         ~w(.jpg .jpeg .png .gif .webp .mp4 .mov .webm .pdf .doc .docx .xls .xlsx .ppt .pptx .csv .txt .zip),
       max_entries: 6,
       max_file_size: 25_000_000
     )
     |> load_sidebar()
     |> reset_channel_form()
     |> maybe_push_initial_chat_notify()}
  end

  def handle_params(%{"channel" => channel_id}, _uri, socket) do
    user = socket.assigns.current_user

    case Chat.get_channel!(String.to_integer(channel_id)) do
      channel ->
        if Chat.member?(channel, user.id) || channel.kind == :public do
          Chat.mark_channel_read(channel, user.id)

          {:noreply,
           socket
           |> subscribe_active_chat_topic(Chat.channel_presence_topic(channel.id))
           |> assign(:active_panel, :channels)
           |> assign(:active_channel, channel)
           |> assign(:active_conversation, nil)
           |> assign(:messages, Chat.list_channel_messages(channel.id))
           |> assign(:mobile_sidebar_open, false)
           |> reset_compose()
           |> track_chat_presence()
           |> load_sidebar()
           |> load_pinned_messages()}
        else
          {:noreply, push_navigate(socket, to: ~p"/app/chat")}
        end
    end
  end

  def handle_params(%{"dm" => conv_id}, _uri, socket) do
    user = socket.assigns.current_user
    conv_id = String.to_integer(conv_id)

    if Chat.conversation_member?(conv_id, user.id) do
      Chat.mark_conversation_read(conv_id, user.id)
      conversation = Chat.get_conversation!(conv_id)

      {:noreply,
       socket
       |> subscribe_active_chat_topic(Chat.conversation_presence_topic(conv_id))
       |> assign(:active_panel, :dms)
       |> assign(:active_channel, nil)
       |> assign(:active_conversation, conversation)
       |> assign(:messages, Chat.list_conversation_messages(conv_id))
       |> assign(:mobile_sidebar_open, false)
       |> reset_compose()
       |> track_chat_presence()
       |> load_sidebar()
       |> load_pinned_messages()}
    else
      {:noreply, push_navigate(socket, to: ~p"/app/chat")}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Events
  # ---------------------------------------------------------------------------

  def handle_event("show_pinned", _params, socket) do
    {:noreply, socket |> load_pinned_messages() |> assign(:active_modal, :pinned_messages)}
  end

  def handle_event("switch_panel", %{"panel" => panel}, socket) do
    {:noreply, assign(socket, :active_panel, String.to_existing_atom(panel))}
  end

  def handle_event("open_sidebar", _params, socket) do
    {:noreply, assign(socket, :mobile_sidebar_open, true)}
  end

  def handle_event("send_message", params, socket) do
    body = String.trim(Map.get(params, "body", ""))
    code_content = String.trim(Map.get(params, "code_content", ""))
    code_language = Map.get(params, "code_language", "plaintext")
    media_caption = String.trim(Map.get(params, "media_caption", ""))
    user = socket.assigns.current_user

    media_attachments =
      consume_uploaded_entries(socket, :chat_media, fn %{path: path}, entry ->
        url = BetaSigma.Uploads.persist_upload!("chat", %{path: path}, entry.client_name)
        att_type = attachment_type(entry.client_type)

        {:ok,
         %{
           "type" => att_type,
           "url" => url,
           "filename" => entry.client_name,
           "caption" => media_caption
         }}
      end)

    code_attachments =
      if socket.assigns.code_mode && code_content != "" do
        [%{"type" => "code", "content" => code_content, "language" => code_language}]
      else
        []
      end

    attachments = media_attachments ++ code_attachments

    if body == "" && Enum.empty?(attachments) do
      {:noreply, socket}
    else
      result =
        cond do
          socket.assigns.active_channel ->
            Chat.send_channel_message(socket.assigns.active_channel.id, user, body,
              attachments: attachments
            )

          socket.assigns.active_conversation ->
            Chat.send_conversation_message(socket.assigns.active_conversation.id, user, body,
              attachments: attachments
            )

          true ->
            {:error, :no_target}
        end

      case result do
        {:ok, _message} ->
          {:noreply, socket |> assign(:draft, "") |> reset_compose()}

        {:error, _} ->
          {:noreply, socket}
      end
    end
  end

  def handle_event("update_draft", %{"body" => value}, socket) do
    {:noreply, assign(socket, :draft, value)}
  end

  def handle_event("insert_emoji", %{"emoji" => emoji}, socket) do
    emoji = if emoji in @quick_reaction_emojis, do: emoji, else: ""
    draft = socket.assigns.draft || ""

    {:noreply, assign(socket, :draft, draft <> emoji)}
  end

  def handle_event("toggle_code_mode", _params, socket) do
    {:noreply, assign(socket, :code_mode, !socket.assigns.code_mode)}
  end

  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :chat_media, ref)}
  end

  def handle_event("delete_message", %{"id" => id}, socket) do
    user = socket.assigns.current_user
    message = Chat.get_message!(String.to_integer(id))
    Chat.delete_message(message, user.id, user.role)
    {:noreply, socket}
  end

  def handle_event("toggle_pin", %{"id" => id}, socket) do
    message_id = String.to_integer(id)
    user_id = socket.assigns.current_user.id

    case Chat.toggle_pin(message_id, user_id) do
      {:ok, updated} ->
        messages =
          Enum.map(socket.assigns.messages, fn message ->
            if message.id == updated.id, do: updated, else: message
          end)

        {:noreply, socket |> assign(:messages, messages) |> load_pinned_messages()}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_event("toggle_reaction", %{"id" => id, "emoji" => emoji}, socket) do
    message_id = String.to_integer(id)
    user_id = socket.assigns.current_user.id

    case Chat.toggle_reaction(message_id, user_id, emoji) do
      {:ok, updated} ->
        messages =
          Enum.map(socket.assigns.messages, fn message ->
            if message.id == updated.id, do: updated, else: message
          end)

        {:noreply, assign(socket, :messages, messages)}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_event("typing", %{"typing" => typing}, socket) do
    user = socket.assigns.current_user

    payload = %{
      user_id: user.id,
      name: user_display_name(user),
      typing: typing in [true, "true"]
    }

    cond do
      socket.assigns.active_channel ->
        Chat.broadcast_channel_typing(socket.assigns.active_channel.id, payload)

      socket.assigns.active_conversation ->
        Chat.broadcast_conversation_typing(socket.assigns.active_conversation.id, payload)

      true ->
        :ok
    end

    {:noreply, socket}
  end

  def handle_event("search_messages", %{"value" => query}, socket) do
    query = String.trim(query)
    results = Chat.search_messages(query, socket.assigns.current_user.id)

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:search_results, results)}
  end

  def handle_event("new_channel", _params, socket) do
    {:noreply,
     socket
     |> reset_channel_form()
     |> assign(:active_modal, :new_channel)
     |> assign(:new_channel_user_query, "")
     |> assign(:new_channel_user_results, [])
     |> assign(:new_channel_selected_users, [])}
  end

  def handle_event("new_dm", _params, socket) do
    {:noreply,
     socket
     |> assign(:active_modal, :new_dm)
     |> assign(:new_dm_query, "")
     |> assign(:new_dm_users, [])}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, socket |> assign(:active_modal, nil) |> reset_channel_form()}
  end

  def handle_event("validate_channel", %{"channel" => attrs}, socket) do
    changeset =
      %Channel{}
      |> Chat.change_channel(attrs)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :channel_changeset, changeset)}
  end

  def handle_event("save_channel", %{"channel" => attrs}, socket) do
    user_ids = Enum.map(socket.assigns.new_channel_selected_users, & &1.id)

    case Chat.create_channel(socket.assigns.current_user, attrs, user_ids) do
      {:ok, channel} ->
        {:noreply,
         socket
         |> assign(:active_modal, nil)
         |> load_sidebar()
         |> push_patch(to: ~p"/app/chat?channel=#{channel.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :channel_changeset, Map.put(changeset, :action, :validate))}
    end
  end

  def handle_event("search_channel_users", %{"value" => query}, socket) do
    query = String.trim(query)

    users =
      if byte_size(query) >= 2 do
        current_user_id = socket.assigns.current_user.id
        selected_ids = Enum.map(socket.assigns.new_channel_selected_users, & &1.id)

        Accounts.list_users()
        |> Enum.filter(fn u ->
          u.id != current_user_id && u.id not in selected_ids &&
            (String.contains?(String.downcase(u.name || ""), String.downcase(query)) ||
               String.contains?(String.downcase(u.email), String.downcase(query)))
        end)
        |> Enum.take(8)
      else
        []
      end

    {:noreply, assign(socket, new_channel_user_query: query, new_channel_user_results: users)}
  end

  def handle_event("add_channel_user", %{"id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
    user = Enum.find(socket.assigns.new_channel_user_results, &(&1.id == user_id))

    if user do
      selected = socket.assigns.new_channel_selected_users ++ [user]

      {:noreply,
       assign(socket,
         new_channel_selected_users: selected,
         new_channel_user_query: "",
         new_channel_user_results: []
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_event("remove_channel_user", %{"id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
    selected = Enum.reject(socket.assigns.new_channel_selected_users, &(&1.id == user_id))
    {:noreply, assign(socket, new_channel_selected_users: selected)}
  end

  def handle_event("manage_members", _params, socket) do
    if channel = socket.assigns.active_channel do
      members = Chat.list_channel_members(channel)
      member_ids = Enum.map(members, & &1.id)
      all_non_members = Accounts.list_users() |> Enum.reject(&(&1.id in member_ids))

      {:noreply,
       socket
       |> assign(:active_modal, :manage_members)
       |> assign(:channel_members, members)
       |> assign(:manage_members_query, "")
       |> assign(:manage_members_results, all_non_members)
       |> assign(:manage_members_all, all_non_members)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("search_new_members", %{"value" => query}, socket) do
    query = String.trim(query)
    all_non_members = socket.assigns.manage_members_all

    users =
      if byte_size(query) == 0 do
        all_non_members
      else
        Enum.filter(all_non_members, fn u ->
          String.contains?(String.downcase(u.name || ""), String.downcase(query)) ||
            String.contains?(String.downcase(u.email), String.downcase(query))
        end)
      end

    {:noreply, assign(socket, manage_members_query: query, manage_members_results: users)}
  end

  def handle_event("add_member_to_channel", %{"id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
    channel = socket.assigns.active_channel
    user = Accounts.get_user!(user_id)

    if channel && user do
      Chat.add_member(channel, user)
      members = Chat.list_channel_members(channel)
      member_ids = Enum.map(members, & &1.id)
      all_non_members = Accounts.list_users() |> Enum.reject(&(&1.id in member_ids))
      query = socket.assigns.manage_members_query

      filtered =
        if byte_size(query) == 0 do
          all_non_members
        else
          Enum.filter(all_non_members, fn u ->
            String.contains?(String.downcase(u.name || ""), String.downcase(query)) ||
              String.contains?(String.downcase(u.email), String.downcase(query))
          end)
        end

      {:noreply,
       socket
       |> assign(:channel_members, members)
       |> assign(:manage_members_all, all_non_members)
       |> assign(:manage_members_results, filtered)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("remove_member_from_channel", %{"id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
    channel = socket.assigns.active_channel
    user = Accounts.get_user!(user_id)

    if channel && user do
      Chat.remove_member(channel, user)
      members = Chat.list_channel_members(channel)
      member_ids = Enum.map(members, & &1.id)
      all_non_members = Accounts.list_users() |> Enum.reject(&(&1.id in member_ids))
      query = socket.assigns.manage_members_query

      filtered =
        if byte_size(query) == 0 do
          all_non_members
        else
          Enum.filter(all_non_members, fn u ->
            String.contains?(String.downcase(u.name || ""), String.downcase(query)) ||
              String.contains?(String.downcase(u.email), String.downcase(query))
          end)
        end

      {:noreply,
       socket
       |> assign(:channel_members, members)
       |> assign(:manage_members_all, all_non_members)
       |> assign(:manage_members_results, filtered)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("search_dm_users", %{"value" => query}, socket) do
    query = String.trim(query)

    users =
      if byte_size(query) >= 2 do
        current_user_id = socket.assigns.current_user.id

        Accounts.list_users()
        |> Enum.filter(fn u ->
          u.id != current_user_id &&
            (String.contains?(String.downcase(u.name || ""), String.downcase(query)) ||
               String.contains?(String.downcase(u.email), String.downcase(query)))
        end)
        |> Enum.take(8)
      else
        []
      end

    {:noreply, socket |> assign(:new_dm_query, query) |> assign(:new_dm_users, users)}
  end

  def handle_event("start_dm", %{"user_id" => user_id}, socket) do
    current_user = socket.assigns.current_user

    case Chat.find_or_create_dm(current_user.id, String.to_integer(user_id)) do
      {:ok, conversation} ->
        {:noreply,
         socket
         |> assign(:active_modal, nil)
         |> load_sidebar()
         |> push_patch(to: ~p"/app/chat?dm=#{conversation.id}")}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  # ---------------------------------------------------------------------------
  # PubSub messages
  # ---------------------------------------------------------------------------

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    {:noreply, assign(socket, :online_users, list_online_users(socket.assigns.presence_topic))}
  end

  def handle_info(%{event: :message_created, message: message}, socket) do
    socket =
      socket
      |> mark_active_message_read(message)
      |> append_message_once(message)
      |> clear_typing_user(message.user_id)
      |> load_sidebar()

    {:noreply, socket}
  end

  def handle_info(%{event: :message_updated, message: updated}, socket) do
    messages =
      Enum.map(socket.assigns.messages, fn m ->
        if m.id == updated.id, do: updated, else: m
      end)

    {:noreply, assign(socket, :messages, messages)}
  end

  def handle_info(%{event: event}, socket)
      when event in [:chat_mention, :chat_new_message] do
    socket = load_sidebar(socket)

    socket =
      push_event(socket, "chat:notify", %{
        unread_count: socket.assigns.chat_unread_count,
        mention: event == :chat_mention
      })

    {:noreply, socket}
  end

  def handle_info(%{event: :typing, user_id: user_id, name: name, typing: typing}, socket) do
    if user_id == socket.assigns.current_user.id do
      {:noreply, socket}
    else
      socket =
        if typing do
          expires_at = System.monotonic_time(:millisecond) + 3_000
          Process.send_after(self(), {:clear_typing, user_id, expires_at}, 3_100)

          update(socket, :typing_users, fn users ->
            Map.put(users, user_id, %{name: name, expires_at: expires_at})
          end)
        else
          clear_typing_user(socket, user_id)
        end

      {:noreply, socket}
    end
  end

  def handle_info({:clear_typing, user_id, expires_at}, socket) do
    {:noreply, clear_typing_user(socket, user_id, expires_at)}
  end

  def handle_info(%{event: event} = payload, socket)
      when event in [
             :notification_created,
             :notification_read,
             :notification_unread,
             :notifications_read_all
           ] do
    {:noreply,
     socket
     |> Realtime.sync_unread_count(Map.get(payload, :unread_count))
     |> Realtime.track_event(payload)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  def render(assigns) do
    assigns =
      assigns
      |> assign(:channel_form, to_form(assigns.channel_changeset, as: :channel))
      |> assign(:messages_with_headers, with_headers(assigns.messages))
      |> assign(:quick_reaction_emojis, @quick_reaction_emojis)

    ~H"""
    <div class="flex h-[calc(96vh-4rem)] overflow-hidden rounded-lg border border-orange-100 bg-white shadow-sm">
      <%!-- Sidebar --%>
      <aside class={[
        "flex-col border-r border-orange-100 bg-gradient-to-b from-orange-50/70 to-white sm:flex sm:w-56 sm:shrink-0",
        if(@mobile_sidebar_open, do: "flex w-full", else: "hidden")
      ]}>
        <%!-- Panel tabs --%>
        <div class="flex gap-1 border-b border-orange-100 p-2">
          <button
            type="button"
            phx-click="switch_panel"
            phx-value-panel="channels"
            class={panel_tab_class(@active_panel == :channels)}
          >
            <span class="flex items-center justify-center gap-1">
              Channels
              <span
                :if={@channel_unread_total > 0}
                class="flex h-4 min-w-[1rem] items-center justify-center rounded bg-[#f26334] px-1 text-[10px] font-semibold text-white"
              >
                {if @channel_unread_total > 99, do: "99+", else: @channel_unread_total}
              </span>
            </span>
          </button>
          <button
            type="button"
            phx-click="switch_panel"
            phx-value-panel="dms"
            class={panel_tab_class(@active_panel == :dms)}
          >
            <span class="flex items-center justify-center gap-1">
              DMs
              <span
                :if={@dm_unread_total > 0}
                class="flex h-4 min-w-[1rem] items-center justify-center rounded bg-[#f26334] px-1 text-[10px] font-semibold text-white"
              >
                {if @dm_unread_total > 99, do: "99+", else: @dm_unread_total}
              </span>
            </span>
          </button>
          <button
            type="button"
            phx-click="switch_panel"
            phx-value-panel="search"
            class={panel_tab_class(@active_panel == :search)}
            title="Search"
          >
            <.icon name="hero-magnifying-glass" class="h-3.5 w-3.5" />
          </button>
        </div>

        <%!-- Channels panel --%>
        <div :if={@active_panel == :channels} class="flex flex-1 flex-col overflow-hidden">
          <div class="flex items-center justify-between px-3 pb-1.5 pt-3">
            <span class="text-xs font-medium text-neutral-400">
              Channels
            </span>
            <button
              type="button"
              phx-click="new_channel"
              class="rounded-md p-1 text-neutral-500 hover:bg-neutral-100"
              title="New channel"
            >
              <.icon name="hero-plus" class="h-3.5 w-3.5" />
            </button>
          </div>
          <nav class="flex-1 space-y-0.5 overflow-y-auto px-2 pb-3">
            <.link
              :for={ch <- @channels}
              patch={~p"/app/chat?channel=#{ch.id}"}
              class={
                sidebar_item_class(
                  @active_channel && @active_channel.id == ch.id,
                  ch.unread_count > 0
                )
              }
            >
              <span class="mr-1 font-normal text-neutral-400">#</span>
              <span class="truncate">{ch.name}</span>
              <span
                :if={ch.unread_count > 0}
                class="ml-auto flex h-4 min-w-[1rem] items-center justify-center rounded bg-[#f26334] px-1 text-[10px] font-semibold text-white"
              >
                {(ch.unread_count > 99 && "99+") || ch.unread_count}
              </span>
            </.link>
            <p :if={@channels == []} class="px-2 py-1 text-sm text-neutral-400">
              No channels yet.
            </p>
          </nav>
        </div>

        <%!-- DMs panel --%>
        <div :if={@active_panel == :dms} class="flex flex-1 flex-col overflow-hidden">
          <div class="flex items-center justify-between px-3 pb-1.5 pt-3">
            <span class="text-xs font-medium text-neutral-400">
              Direct messages
            </span>
            <button
              type="button"
              phx-click="new_dm"
              class="rounded-md p-1 text-neutral-500 hover:bg-neutral-100"
              title="New DM"
            >
              <.icon name="hero-plus" class="h-3.5 w-3.5" />
            </button>
          </div>
          <nav class="flex-1 space-y-0.5 overflow-y-auto px-2 pb-3">
            <.link
              :for={conv <- @conversations}
              patch={~p"/app/chat?dm=#{conv.id}"}
              class={
                sidebar_item_class(
                  @active_conversation && @active_conversation.id == conv.id,
                  conv.unread_count > 0
                )
              }
            >
              <div class="relative mr-2">
                <.avatar user={dm_other_user(conv, @current_user)} class="h-6 w-6 text-[9px]" />
                <span
                  :if={online_user?(dm_other_user(conv, @current_user), @online_users)}
                  class="absolute -bottom-0.5 -right-0.5 h-2.5 w-2.5 rounded-full border-2 border-neutral-50 bg-emerald-500"
                >
                </span>
              </div>
              <span class="truncate">{dm_label(conv, @current_user)}</span>
              <span
                :if={conv.unread_count > 0}
                class="ml-auto flex h-4 min-w-[1rem] items-center justify-center rounded bg-[#f26334] px-1 text-[10px] font-semibold text-white"
              >
                {(conv.unread_count > 99 && "99+") || conv.unread_count}
              </span>
            </.link>
            <p :if={@conversations == []} class="px-2 py-1 text-sm text-neutral-400">
              No conversations yet.
            </p>
          </nav>
        </div>

        <%!-- Search panel --%>
        <div :if={@active_panel == :search} class="flex flex-1 flex-col overflow-hidden">
          <div class="px-3 pb-1.5 pt-3">
            <span class="text-xs font-medium text-neutral-400">
              Search
            </span>
            <input
              type="text"
              value={@search_query}
              placeholder="Search messages..."
              phx-keyup="search_messages"
              class="mt-2 w-full rounded-md border border-neutral-200 bg-white px-3 py-2 text-sm text-neutral-900 focus:border-[#f26334] focus:ring-2 focus:ring-[#f26334]/30 focus:outline-none"
            />
          </div>
          <div class="flex-1 space-y-1 overflow-y-auto px-2 pb-3">
            <p
              :if={@search_results == [] and @search_query != ""}
              class="px-2 py-1 text-xs text-neutral-400"
            >
              No results.
            </p>
            <article
              :for={msg <- @search_results}
              class="rounded-lg border border-neutral-200 bg-white p-2.5"
            >
              <p class="truncate text-xs font-semibold text-neutral-900">
                {user_display_name(msg.user)}
              </p>
              <p class="mt-0.5 line-clamp-2 text-xs text-neutral-500">{msg.body}</p>
              <p class="mt-1 text-[10px] text-neutral-400">{format_time(msg.inserted_at)}</p>
            </article>
          </div>
        </div>
      </aside>

      <%!-- Main content --%>
      <div class={[
        "min-w-0 flex-1 flex-col overflow-hidden sm:flex",
        if(@mobile_sidebar_open, do: "hidden", else: "flex")
      ]}>
        <%!-- Header --%>
        <div
          :if={@active_channel || @active_conversation}
          class="flex h-13 shrink-0 items-center gap-3 border-b border-orange-100 bg-white px-3 sm:px-5 py-2.5"
        >
          <button
            type="button"
            phx-click="open_sidebar"
            class="sm:hidden -ml-0.5 rounded-md p-1.5 text-neutral-500 hover:bg-neutral-100"
            title="Back"
          >
            <.icon name="hero-chevron-left" class="h-5 w-5" />
          </button>
          <div :if={@active_channel} class="flex flex-1 items-center justify-between">
            <div class="flex items-center gap-2">
              <span class="text-lg font-light text-neutral-400">#</span>
              <h2 class="text-sm font-semibold text-neutral-900">{@active_channel.name}</h2>
              <span :if={@active_channel.topic} class="ml-1 text-xs text-neutral-400">
                — {@active_channel.topic}
              </span>
              <span class="ml-1 flex items-center gap-1 text-xs text-neutral-500">
                <span class="h-1.5 w-1.5 rounded-full bg-emerald-500"></span>
                {online_count(@online_users)} online
              </span>
            </div>
            <div class="flex items-center gap-1.5">
              <button
                type="button"
                phx-click="show_pinned"
                class="flex items-center gap-1.5 rounded-md px-2.5 py-1.5 text-xs font-medium text-neutral-500 hover:bg-neutral-100"
              >
                <.icon name="hero-map-pin" class="h-4 w-4" />
                <span>Pinned</span>
                <span
                  :if={@pinned_messages != []}
                  class="flex h-4 min-w-[1rem] items-center justify-center rounded bg-[#f26334] px-1 text-[10px] font-semibold text-white"
                >
                  {length(@pinned_messages)}
                </span>
              </button>
              <button
                type="button"
                phx-click="manage_members"
                class="flex items-center gap-1.5 rounded-md px-2.5 py-1.5 text-xs font-medium text-neutral-500 hover:bg-neutral-100"
              >
                <.icon name="hero-users" class="h-4 w-4" />
                <span>Members</span>
              </button>
            </div>
          </div>
          <div :if={@active_conversation} class="flex flex-1 items-center justify-between">
            <div class="flex items-center gap-2.5">
              <div class="relative">
                <.avatar
                  user={dm_other_user(@active_conversation, @current_user)}
                  class="h-7 w-7 text-[10px]"
                />
                <span
                  :if={
                    online_user?(dm_other_user(@active_conversation, @current_user), @online_users)
                  }
                  class="absolute -bottom-0.5 -right-0.5 h-2.5 w-2.5 rounded-full border-2 border-white bg-emerald-500"
                >
                </span>
              </div>
              <div>
                <h2 class="text-sm font-semibold text-neutral-900">
                  {dm_label(@active_conversation, @current_user)}
                </h2>
                <p class="text-[11px] text-neutral-400">
                  {if online_user?(dm_other_user(@active_conversation, @current_user), @online_users),
                    do: "Online",
                    else: "Offline"}
                </p>
              </div>
            </div>
            <button
              type="button"
              phx-click="show_pinned"
              class="flex items-center gap-1.5 rounded-md px-2.5 py-1.5 text-xs font-medium text-neutral-500 hover:bg-neutral-100"
            >
              <.icon name="hero-map-pin" class="h-4 w-4" />
              <span>Pinned</span>
              <span
                :if={@pinned_messages != []}
                class="flex h-4 min-w-[1rem] items-center justify-center rounded bg-[#f26334] px-1 text-[10px] font-semibold text-white"
              >
                {length(@pinned_messages)}
              </span>
            </button>
          </div>
        </div>

        <%!-- Empty state --%>
        <div
          :if={!@active_channel && !@active_conversation}
          class="flex flex-1 items-center justify-center"
        >
          <div class="text-center">
            <.icon name="hero-chat-bubble-left-right" class="mx-auto h-10 w-10 text-neutral-300" />
            <p class="mt-3 text-sm text-neutral-500">Select a channel or DM to start chatting</p>
          </div>
        </div>

        <%!-- Messages --%>
        <div
          :if={@active_channel || @active_conversation}
          id="messages-container"
          phx-hook="ScrollToBottom"
          data-chat-key={active_chat_key(@active_channel, @active_conversation)}
          class="flex-1 overflow-y-auto bg-orange-50/30 px-3 py-4 sm:px-5"
        >
          <div :if={@messages == []} class="flex h-full items-center justify-center">
            <p class="text-sm text-neutral-500">No messages yet — say hello!</p>
          </div>

          <div class="space-y-0.5">
            <article
              :for={{msg, show_header} <- @messages_with_headers}
              id={"msg-#{msg.id}"}
              class={[
                "group rounded-md px-2 py-0.5 hover:bg-white/80",
                msg.user_id == @current_user.id && "bg-[#f26334]/[0.06]",
                show_header && "mt-4 first:mt-0"
              ]}
            >
              <%!-- Header row: avatar + name + time --%>
              <div :if={show_header} class="flex items-start gap-3">
                <.avatar user={msg.user} class="mt-0.5 h-8 w-8 text-xs" />
                <div class="flex-1 min-w-0">
                  <div class="flex items-baseline gap-2">
                    <span class="text-sm font-semibold text-neutral-900">
                      {user_display_name(msg.user)}
                    </span>
                    <span class="text-[11px] text-neutral-400">{format_time(msg.inserted_at)}</span>
                    <span :if={msg.edited_at} class="text-[11px] text-neutral-400">(edited)</span>
                    <span
                      :if={msg.pinned_at}
                      class="inline-flex items-center gap-0.5 text-[11px] font-medium text-[#f26334]"
                    >
                      <.icon name="hero-map-pin" class="h-3 w-3" /> Pinned
                    </span>
                  </div>
                  <div :if={is_nil(msg.deleted_at)}>
                    <p
                      :if={msg.body && String.trim(msg.body) != ""}
                      class="mt-0.5 break-words text-sm leading-6 text-neutral-700"
                    >
                      {render_message_body(msg.body, @current_user.id)}
                    </p>
                    <.message_attachments attachments={msg.attachments || []} message_id={msg.id} />
                    <.message_reactions
                      message={msg}
                      current_user={@current_user}
                      quick_emojis={@quick_reaction_emojis}
                    />
                  </div>
                  <p :if={msg.deleted_at} class="mt-0.5 text-sm italic text-neutral-400">
                    Message deleted.
                  </p>
                </div>
                <div
                  :if={is_nil(msg.deleted_at)}
                  class="flex items-center opacity-0 transition-opacity group-hover:opacity-100"
                >
                  <button
                    type="button"
                    phx-click="toggle_pin"
                    phx-value-id={msg.id}
                    class={[
                      "rounded-md p-1 hover:bg-neutral-100",
                      if(msg.pinned_at,
                        do: "text-[#f26334]",
                        else: "text-neutral-400 hover:text-neutral-700"
                      )
                    ]}
                    title={if msg.pinned_at, do: "Unpin", else: "Pin"}
                  >
                    <.icon name="hero-map-pin" class="h-3.5 w-3.5" />
                  </button>
                  <button
                    :if={msg.user_id == @current_user.id || @current_user.role == :admin}
                    type="button"
                    phx-click="delete_message"
                    phx-value-id={msg.id}
                    data-confirm="Delete this message?"
                    class="rounded-md p-1 text-neutral-400 hover:bg-red-50 hover:text-red-600"
                    title="Delete"
                  >
                    <.icon name="hero-trash" class="h-3.5 w-3.5" />
                  </button>
                </div>
              </div>

              <%!-- Continuation row: indented, no avatar --%>
              <div :if={!show_header} class="flex items-start gap-3">
                <div class="w-8 shrink-0"></div>
                <div class="flex-1 min-w-0">
                  <span
                    :if={msg.pinned_at}
                    class="mb-0.5 inline-flex items-center gap-0.5 text-[11px] font-medium text-[#f26334]"
                  >
                    <.icon name="hero-map-pin" class="h-3 w-3" /> Pinned
                  </span>
                  <div :if={is_nil(msg.deleted_at)}>
                    <p
                      :if={msg.body && String.trim(msg.body) != ""}
                      class="break-words text-sm leading-6 text-neutral-700"
                    >
                      {render_message_body(msg.body, @current_user.id)}
                    </p>
                    <.message_attachments attachments={msg.attachments || []} message_id={msg.id} />
                    <.message_reactions
                      message={msg}
                      current_user={@current_user}
                      quick_emojis={@quick_reaction_emojis}
                    />
                  </div>
                  <p :if={msg.deleted_at} class="text-sm italic text-neutral-400">
                    Message deleted.
                  </p>
                </div>
                <div
                  :if={is_nil(msg.deleted_at)}
                  class="flex items-center opacity-0 transition-opacity group-hover:opacity-100"
                >
                  <button
                    type="button"
                    phx-click="toggle_pin"
                    phx-value-id={msg.id}
                    class={[
                      "rounded-md p-1 hover:bg-neutral-100",
                      if(msg.pinned_at,
                        do: "text-[#f26334]",
                        else: "text-neutral-400 hover:text-neutral-700"
                      )
                    ]}
                    title={if msg.pinned_at, do: "Unpin", else: "Pin"}
                  >
                    <.icon name="hero-map-pin" class="h-3.5 w-3.5" />
                  </button>
                  <button
                    :if={msg.user_id == @current_user.id || @current_user.role == :admin}
                    type="button"
                    phx-click="delete_message"
                    phx-value-id={msg.id}
                    data-confirm="Delete this message?"
                    class="rounded-md p-1 text-neutral-400 hover:bg-red-50 hover:text-red-600"
                    title="Delete"
                  >
                    <.icon name="hero-trash" class="h-3.5 w-3.5" />
                  </button>
                </div>
              </div>
            </article>
          </div>
        </div>

        <%!-- Compose area --%>
        <div
          :if={@active_channel || @active_conversation}
          class="shrink-0 border-t border-orange-100 bg-white px-3 py-3 sm:px-5"
        >
          <p :if={typing_label(@typing_users)} class="mb-2 text-xs text-neutral-500">
            {typing_label(@typing_users)}
          </p>
          <form id="msg-form" phx-submit="send_message" phx-change="validate_upload">
            <%!-- Code editor panel --%>
            <div :if={@code_mode} class="mb-2 overflow-hidden rounded-md border border-neutral-800">
              <div class="flex items-center justify-between bg-neutral-800 px-3 py-2">
                <select
                  name="code_language"
                  class="rounded-md bg-neutral-700 px-2 py-1 text-xs text-neutral-200 focus:outline-none focus:ring-1 focus:ring-neutral-500"
                >
                  <option value="plaintext">Plain text</option>
                  <option value="bash">Bash / Shell</option>
                  <option value="css">CSS</option>
                  <option value="elixir">Elixir</option>
                  <option value="go">Go</option>
                  <option value="html">HTML</option>
                  <option value="javascript">JavaScript</option>
                  <option value="json">JSON</option>
                  <option value="python">Python</option>
                  <option value="ruby">Ruby</option>
                  <option value="rust">Rust</option>
                  <option value="sql">SQL</option>
                  <option value="typescript">TypeScript</option>
                </select>
                <button
                  type="button"
                  phx-click="toggle_code_mode"
                  class="rounded-md p-1 text-neutral-400 hover:bg-neutral-700 hover:text-neutral-200"
                  title="Close code editor"
                >
                  <.icon name="hero-x-mark" class="h-4 w-4" />
                </button>
              </div>
              <textarea
                name="code_content"
                rows="6"
                placeholder="Paste or type your code here…"
                class="w-full resize-none bg-neutral-900 px-4 py-3 font-mono text-sm text-neutral-100 placeholder-neutral-500 focus:outline-none"
              ></textarea>
            </div>

            <%!-- Media previews --%>
            <div :if={@uploads.chat_media.entries != []} class="mb-2 space-y-2">
              <div class="flex flex-wrap gap-2">
                <div :for={entry <- @uploads.chat_media.entries} class="relative">
                  <.live_img_preview
                    :if={String.starts_with?(entry.client_type, "image/")}
                    entry={entry}
                    class="h-20 w-20 rounded-md border border-neutral-200 object-cover"
                  />
                  <div
                    :if={String.starts_with?(entry.client_type, "video/")}
                    class="flex h-20 w-24 flex-col items-center justify-center gap-1 rounded-md border border-neutral-200 bg-neutral-50"
                  >
                    <.icon name="hero-film" class="h-6 w-6 text-neutral-500" />
                    <span class="line-clamp-1 px-1 text-center text-[10px] text-neutral-500">
                      {entry.client_name}
                    </span>
                  </div>
                  <div
                    :if={
                      !String.starts_with?(entry.client_type, "image/") &&
                        !String.starts_with?(entry.client_type, "video/")
                    }
                    class="flex h-20 w-24 flex-col items-center justify-center gap-1 rounded-md border border-neutral-200 bg-neutral-50"
                  >
                    <.icon name="hero-paper-clip" class="h-6 w-6 text-neutral-500" />
                    <span class="line-clamp-1 px-1 text-center text-[10px] text-neutral-500">
                      {entry.client_name}
                    </span>
                  </div>
                  <button
                    type="button"
                    phx-click="cancel_upload"
                    phx-value-ref={entry.ref}
                    class="absolute -right-1.5 -top-1.5 rounded-full bg-neutral-700 p-0.5 text-white"
                  >
                    <.icon name="hero-x-mark" class="h-3 w-3" />
                  </button>
                  <p
                    :for={err <- upload_errors(@uploads.chat_media, entry)}
                    class="mt-0.5 text-[10px] text-red-600"
                  >
                    {upload_error_msg(err)}
                  </p>
                </div>
              </div>
              <input
                type="text"
                name="media_caption"
                placeholder="Add a caption (optional)…"
                class="w-full rounded-md border border-neutral-200 bg-white px-3 py-2 text-sm text-neutral-900 focus:border-[#f26334] focus:ring-2 focus:ring-[#f26334]/30 focus:outline-none"
              />
            </div>

            <%!-- Main compose row --%>
            <div class="flex items-end gap-2">
              <textarea
                id="chat-input"
                name="body"
                value={@draft}
                data-draft-value={@draft}
                phx-change="update_draft"
                phx-hook="ChatCompose"
                data-mention-users={Jason.encode!(@mention_users)}
                placeholder={compose_placeholder(@active_channel, @active_conversation)}
                rows="1"
                class="max-h-32 flex-1 resize-none rounded-md border border-neutral-200 bg-white px-3 py-2 text-sm text-neutral-900 focus:border-[#f26334] focus:ring-2 focus:ring-[#f26334]/30 focus:outline-none"
              />
              <button
                type="submit"
                disabled={
                  String.trim(@draft) == "" && @uploads.chat_media.entries == [] && !@code_mode
                }
                class="shrink-0 rounded-md bg-[#f26334] px-3 py-2 text-sm font-medium text-white hover:bg-[#d9532a] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#f26334]/40 disabled:cursor-not-allowed disabled:opacity-40"
              >
                Send
              </button>
            </div>

            <%!-- Toolbar --%>
            <div class="mt-2 flex items-center gap-1">
              <label
                class="flex cursor-pointer items-center gap-1.5 rounded-md px-2 py-1 text-xs font-medium text-neutral-500 hover:bg-neutral-100"
                title="Attach photo, video, or document"
              >
                <.icon name="hero-paper-clip" class="h-4 w-4" />
                <span>Attach file</span>
                <.live_file_input upload={@uploads.chat_media} class="sr-only" />
              </label>
              <button
                type="button"
                phx-click="toggle_code_mode"
                title="Insert code block"
                class={[
                  "flex items-center gap-1.5 rounded-md px-2 py-1 text-xs font-medium",
                  if(@code_mode,
                    do: "bg-neutral-100 text-neutral-900",
                    else: "text-neutral-500 hover:bg-neutral-100"
                  )
                ]}
              >
                <.icon name="hero-code-bracket" class="h-4 w-4" />
                <span>Code</span>
              </button>
              <div class="ml-1 flex items-center gap-0.5">
                <button
                  :for={emoji <- @quick_reaction_emojis}
                  type="button"
                  phx-click="insert_emoji"
                  phx-value-emoji={emoji}
                  class="flex h-7 w-7 items-center justify-center rounded-md text-sm text-neutral-500 hover:bg-neutral-100"
                  title={"Insert #{emoji}"}
                  aria-label={"Insert #{emoji}"}
                >
                  {emoji}
                </button>
              </div>
              <span class="ml-auto text-[10px] text-neutral-400">
                Enter to send · Shift+Enter for new line
              </span>
            </div>
          </form>
        </div>
      </div>

      <%!-- New Channel Modal --%>
      <.modal
        :if={@active_modal == :new_channel}
        id="new-channel-modal"
        show
        on_cancel={JS.push("close_modal")}
      >
        <h3 class="text-base font-semibold text-neutral-900">Create a channel</h3>
        <p class="mt-1 text-sm text-neutral-500">
          Channels bring teams together around a topic, project, or team.
        </p>
        <.simple_form
          for={@channel_form}
          id="channel-form"
          phx-change="validate_channel"
          phx-submit="save_channel"
          class="mt-6"
        >
          <div class="space-y-5">
            <.input field={@channel_form[:name]} label="Channel name" placeholder="e.g. engineering" />
            <.input
              field={@channel_form[:kind]}
              type="select"
              label="Type"
              options={[{"Public", "public"}, {"Private", "private"}]}
            />
            <.input
              field={@channel_form[:topic]}
              label="Topic (optional)"
              placeholder="What's this channel about?"
            />

            <div class="mt-4">
              <label class="block text-sm font-medium text-neutral-700">Add members</label>
              <div class="mt-2 flex flex-wrap gap-2">
                <span
                  :for={user <- @new_channel_selected_users}
                  class="inline-flex items-center gap-x-1.5 rounded-md bg-neutral-100 px-2 py-0.5 text-xs font-medium text-neutral-700"
                >
                  {user.name || user.email}
                  <button
                    type="button"
                    phx-click="remove_channel_user"
                    phx-value-id={user.id}
                    class="text-neutral-400 hover:text-neutral-600"
                  >
                    <.icon name="hero-x-mark" class="h-3 w-3" />
                  </button>
                </span>
              </div>
              <input
                type="text"
                value={@new_channel_user_query}
                placeholder="Search users to add..."
                phx-keyup="search_channel_users"
                class="mt-2 w-full rounded-md border border-neutral-200 bg-white px-3 py-2 text-sm text-neutral-900 focus:border-[#f26334] focus:ring-2 focus:ring-[#f26334]/30 focus:outline-none"
              />
              <div
                :if={@new_channel_user_results != []}
                class="mt-2 max-h-40 overflow-y-auto rounded-md border border-neutral-200 bg-white shadow-md"
              >
                <button
                  :for={user <- @new_channel_user_results}
                  type="button"
                  phx-click="add_channel_user"
                  phx-value-id={user.id}
                  class="flex w-full items-center gap-3 px-3 py-1.5 text-left text-sm hover:bg-neutral-100"
                >
                  <.avatar user={user} class="h-6 w-6 text-[10px]" />
                  <div>
                    <p class="text-sm font-medium text-neutral-900">{user.name || user.email}</p>
                  </div>
                </button>
              </div>
            </div>
          </div>
          <:actions>
            <button
              type="button"
              phx-click="close_modal"
              class="rounded-md border border-neutral-200 bg-white px-3 py-1.5 text-sm font-medium text-neutral-700 hover:bg-neutral-50"
            >
              Cancel
            </button>
            <.button>Create channel</.button>
          </:actions>
        </.simple_form>
      </.modal>

      <%!-- New DM Modal --%>
      <.modal :if={@active_modal == :new_dm} id="new-dm-modal" show on_cancel={JS.push("close_modal")}>
        <h3 class="text-base font-semibold text-neutral-900">Start a DM</h3>
        <p class="mt-1 text-sm text-neutral-500">
          Search for a team member to message directly.
        </p>
        <div class="mt-6">
          <input
            type="text"
            value={@new_dm_query}
            placeholder="Search by name or email..."
            phx-keyup="search_dm_users"
            class="w-full rounded-md border border-neutral-200 bg-white px-3 py-2 text-sm text-neutral-900 focus:border-[#f26334] focus:ring-2 focus:ring-[#f26334]/30 focus:outline-none"
            autofocus
          />
        </div>
        <div
          :if={@new_dm_users != []}
          class="mt-4 divide-y divide-neutral-200 rounded-lg border border-neutral-200"
        >
          <button
            :for={user <- @new_dm_users}
            type="button"
            phx-click="start_dm"
            phx-value-user_id={user.id}
            class="flex w-full items-center gap-3 px-3 py-2 text-left first:rounded-t-lg last:rounded-b-lg hover:bg-neutral-50"
          >
            <.avatar user={user} class="h-8 w-8 text-xs" />
            <div>
              <p class="text-sm font-medium text-neutral-900">{user.name || user.email}</p>
              <p class="text-xs text-neutral-500">{user.email}</p>
            </div>
          </button>
        </div>
        <div
          :if={@new_dm_users == [] and byte_size(@new_dm_query) >= 2}
          class="mt-4 text-sm text-neutral-500"
        >
          No users found.
        </div>
      </.modal>

      <%!-- Manage Members Modal --%>
      <.modal
        :if={@active_modal == :manage_members}
        id="manage-members-modal"
        show
        on_cancel={JS.push("close_modal")}
      >
        <div class="flex items-center justify-between">
          <h3 class="text-base font-semibold text-neutral-900">Manage members</h3>
        </div>

        <div class="mt-4">
          <input
            type="text"
            value={@manage_members_query}
            placeholder="Search users to add..."
            phx-keyup="search_new_members"
            autofocus
            class="w-full rounded-md border border-neutral-200 bg-white px-3 py-2 text-sm text-neutral-900 focus:border-[#f26334] focus:ring-2 focus:ring-[#f26334]/30 focus:outline-none"
          />
          <div class="mt-2 max-h-48 overflow-y-auto rounded-md border border-neutral-200 bg-white shadow-md">
            <button
              :for={user <- @manage_members_results}
              type="button"
              phx-click="add_member_to_channel"
              phx-value-id={user.id}
              class="flex w-full items-center gap-3 px-3 py-2 text-left hover:bg-neutral-100 border-b border-neutral-200 last:border-0"
            >
              <.avatar user={user} class="h-7 w-7 text-[10px]" />
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium text-neutral-900 truncate">{user.name || user.email}</p>
                <p class="text-xs text-neutral-400 truncate">{user.email}</p>
              </div>
              <span class="shrink-0 text-xs font-medium text-[#f26334]">Add</span>
            </button>
            <p
              :if={@manage_members_results == []}
              class="px-3 py-4 text-sm text-neutral-400 text-center"
            >
              {if byte_size(@manage_members_query) > 0,
                do: "No users match your search.",
                else: "All users are already members."}
            </p>
          </div>
        </div>

        <div class="mt-5">
          <h4 class="text-xs font-medium text-neutral-500">
            Current members
          </h4>
          <ul class="mt-3 max-h-52 overflow-y-auto divide-y divide-neutral-200">
            <li :for={member <- @channel_members} class="flex items-center justify-between py-2.5">
              <div class="flex items-center gap-3">
                <.avatar user={member} class="h-8 w-8 text-xs" />
                <div>
                  <p class="text-sm font-medium text-neutral-900">{member.name || member.email}</p>
                  <p class="text-xs text-neutral-500">{member.email}</p>
                </div>
              </div>
              <button
                :if={member.id != @current_user.id}
                type="button"
                phx-click="remove_member_from_channel"
                phx-value-id={member.id}
                data-confirm="Are you sure you want to remove this member?"
                class="rounded-md px-2 py-1 text-xs font-medium text-red-600 hover:bg-red-50"
              >
                Remove
              </button>
              <span :if={member.id == @current_user.id} class="text-xs text-neutral-400">You</span>
            </li>
          </ul>
        </div>
      </.modal>

      <%!-- Pinned Messages Modal --%>
      <.modal
        :if={@active_modal == :pinned_messages}
        id="pinned-messages-modal"
        show
        on_cancel={JS.push("close_modal")}
      >
        <h3 class="text-base font-semibold text-neutral-900">Pinned messages</h3>
        <div class="mt-4 max-h-96 space-y-3 overflow-y-auto">
          <article
            :for={msg <- @pinned_messages}
            class="rounded-lg border border-neutral-200 bg-white p-3"
          >
            <div class="flex items-start justify-between gap-2">
              <div class="flex items-center gap-2">
                <.avatar user={msg.user} class="h-6 w-6 text-[9px]" />
                <span class="text-sm font-semibold text-neutral-900">
                  {user_display_name(msg.user)}
                </span>
                <span class="text-[11px] text-neutral-400">{format_time(msg.inserted_at)}</span>
              </div>
              <button
                type="button"
                phx-click="toggle_pin"
                phx-value-id={msg.id}
                class="rounded-md p-1 text-[#f26334] hover:bg-neutral-100"
                title="Unpin"
              >
                <.icon name="hero-map-pin" class="h-3.5 w-3.5" />
              </button>
            </div>
            <p
              :if={msg.body && String.trim(msg.body) != ""}
              class="mt-1.5 break-words text-sm text-neutral-700"
            >
              {render_message_body(msg.body, @current_user.id)}
            </p>
            <.message_attachments attachments={msg.attachments || []} message_id={msg.id} />
          </article>
          <p :if={@pinned_messages == []} class="py-4 text-center text-sm text-neutral-400">
            No pinned messages yet.
          </p>
        </div>
      </.modal>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Attachment renderer component
  # ---------------------------------------------------------------------------

  defp message_attachments(%{attachments: []} = assigns), do: ~H""
  defp message_attachments(%{attachments: nil} = assigns), do: ~H""

  defp message_attachments(assigns) do
    assigns =
      assigns
      |> assign(
        :media_attachments,
        assigns.attachments
        |> Enum.filter(&(&1["type"] in ["image", "video"]))
        |> Enum.with_index()
      )
      |> assign(
        :file_attachments,
        assigns.attachments |> Enum.filter(&(&1["type"] == "file")) |> Enum.with_index()
      )

    ~H"""
    <div class="mt-2 space-y-2">
      <%!-- Image / video grid --%>
      <div :if={@media_attachments != []} class="flex flex-wrap gap-2">
        <div :for={{att, idx} <- @media_attachments} class="space-y-1">
          <button
            :if={att["type"] == "image"}
            type="button"
            phx-click={JS.show(to: "#lb-#{@message_id}-#{idx}", display: "flex")}
            class="block cursor-zoom-in"
            title="View full size"
          >
            <img
              src={att["url"]}
              alt={att["caption"] || att["filename"] || "image"}
              class="max-h-72 max-w-xs rounded-md border border-neutral-200 object-cover transition-opacity hover:opacity-90"
            />
          </button>
          <div :if={att["type"] == "video"} class="group relative">
            <video
              src={att["url"]}
              controls
              muted
              playsinline
              class="max-h-72 max-w-xs rounded-md border border-neutral-200"
            >
            </video>
            <button
              type="button"
              phx-click={JS.show(to: "#lb-#{@message_id}-#{idx}", display: "flex")}
              class="absolute right-1.5 top-1.5 rounded-md bg-black/60 p-1 text-white opacity-0 transition-opacity group-hover:opacity-100"
              title="View full screen"
            >
              <.icon name="hero-arrows-pointing-out" class="h-4 w-4" />
            </button>
          </div>
          <p :if={att["caption"] && att["caption"] != ""} class="text-xs text-neutral-500">
            {att["caption"]}
          </p>

          <%!-- Full-view lightbox --%>
          <div
            id={"lb-#{@message_id}-#{idx}"}
            class="fixed inset-0 z-[1000] hidden items-center justify-center bg-black/85 p-4"
            phx-click={JS.hide(to: "#lb-#{@message_id}-#{idx}")}
            phx-window-keydown={JS.hide(to: "#lb-#{@message_id}-#{idx}")}
            phx-key="escape"
          >
            <button
              type="button"
              phx-click={JS.hide(to: "#lb-#{@message_id}-#{idx}")}
              class="absolute right-4 top-4 rounded-md bg-black/60 p-1.5 text-white hover:bg-black/80"
              title="Close"
            >
              <.icon name="hero-x-mark" class="h-5 w-5" />
            </button>
            <img
              :if={att["type"] == "image"}
              src={att["url"]}
              alt={att["caption"] || att["filename"] || "image"}
              class="max-h-full max-w-full rounded-md object-contain"
            />
            <video
              :if={att["type"] == "video"}
              src={att["url"]}
              controls
              autoplay
              playsinline
              class="max-h-full max-w-full rounded-md"
            >
            </video>
          </div>
        </div>
      </div>

      <%!-- Documents / generic files --%>
      <div
        :for={{att, idx} <- @file_attachments}
        class="flex max-w-xs items-center gap-2 rounded-md border border-neutral-200 bg-neutral-50 px-3 py-2"
      >
        <.icon name="hero-document" class="h-5 w-5 shrink-0 text-neutral-500" />
        <a
          href={att["url"]}
          target="_blank"
          rel="noopener noreferrer"
          download={att["filename"]}
          class="truncate text-sm font-medium text-[#f26334] underline underline-offset-2 hover:text-[#d9532a]"
        >
          {att["filename"] || "Download file"}
        </a>
        <button
          :if={String.ends_with?(String.downcase(att["filename"] || att["url"] || ""), ".pdf")}
          type="button"
          phx-click={JS.show(to: "#lb-file-#{@message_id}-#{idx}", display: "flex")}
          class="ml-auto shrink-0 rounded-md p-1 text-neutral-400 hover:bg-neutral-100 hover:text-neutral-700"
          title="View"
        >
          <.icon name="hero-arrows-pointing-out" class="h-4 w-4" />
        </button>

        <div
          :if={String.ends_with?(String.downcase(att["filename"] || att["url"] || ""), ".pdf")}
          id={"lb-file-#{@message_id}-#{idx}"}
          class="fixed inset-0 z-[1000] hidden items-center justify-center bg-black/85 p-4"
          phx-window-keydown={JS.hide(to: "#lb-file-#{@message_id}-#{idx}")}
          phx-key="escape"
        >
          <button
            type="button"
            phx-click={JS.hide(to: "#lb-file-#{@message_id}-#{idx}")}
            class="absolute right-4 top-4 rounded-md bg-black/60 p-1.5 text-white hover:bg-black/80"
            title="Close"
          >
            <.icon name="hero-x-mark" class="h-5 w-5" />
          </button>
          <iframe src={att["url"]} class="h-full w-full max-w-4xl rounded-md bg-white"></iframe>
        </div>
      </div>

      <%!-- Code blocks --%>
      <div
        :for={att <- Enum.filter(@attachments, &(&1["type"] == "code"))}
        class="overflow-hidden rounded-md border border-neutral-800"
      >
        <div class="flex items-center gap-2 bg-neutral-800 px-3 py-2">
          <span class="inline-flex items-center gap-1 rounded bg-neutral-700 px-2 py-0.5 font-mono text-[11px] font-medium text-neutral-300">
            <.icon name="hero-code-bracket" class="h-3 w-3" />
            {att["language"] || "code"}
          </span>
        </div>
        <pre class="overflow-x-auto bg-neutral-900 px-4 py-3 text-sm leading-relaxed text-neutral-100"><code class="font-mono">{att["content"]}</code></pre>
      </div>
    </div>
    """
  end

  defp message_reactions(assigns) do
    assigns =
      assigns
      |> assign(:grouped_reactions, grouped_reactions(assigns.message.reactions || []))

    ~H"""
    <div :if={is_nil(@message.deleted_at)} class="mt-2 flex flex-wrap items-center gap-1">
      <button
        :for={emoji <- @quick_emojis}
        type="button"
        phx-click="toggle_reaction"
        phx-value-id={@message.id}
        phx-value-emoji={emoji}
        class={[
          "flex h-7 min-w-7 items-center justify-center rounded-md border px-1.5 text-sm transition-colors",
          reacted?(@grouped_reactions, emoji, @current_user.id) &&
            "border-[#f26334]/30 bg-[#f26334]/10 text-[#f26334]",
          !reacted?(@grouped_reactions, emoji, @current_user.id) &&
            "border-transparent text-neutral-400 opacity-0 hover:border-neutral-200 hover:bg-neutral-100 hover:text-neutral-700 group-hover:opacity-100"
        ]}
        title={"React #{emoji}"}
        aria-label={"React #{emoji}"}
      >
        {emoji}
      </button>
      <button
        :for={{emoji, reaction} <- @grouped_reactions}
        :if={emoji not in @quick_emojis}
        type="button"
        phx-click="toggle_reaction"
        phx-value-id={@message.id}
        phx-value-emoji={emoji}
        class={[
          "flex h-7 items-center gap-1 rounded-md border px-2 text-sm transition-colors",
          reacted?(reaction, @current_user.id) &&
            "border-[#f26334]/30 bg-[#f26334]/10 text-[#f26334]",
          !reacted?(reaction, @current_user.id) &&
            "border-neutral-200 bg-white text-neutral-600 hover:bg-neutral-100"
        ]}
        title={"React #{emoji}"}
        aria-label={"React #{emoji}"}
      >
        <span>{emoji}</span>
        <span class="text-[11px] font-medium">{reaction.count}</span>
      </button>
      <span
        :for={{emoji, reaction} <- @grouped_reactions}
        :if={emoji in @quick_emojis && reaction.count > 0}
        class="ml-0.5 rounded bg-neutral-100 px-1.5 text-[11px] font-medium text-neutral-500"
      >
        {emoji} {reaction.count}
      </span>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp reset_compose(socket) do
    socket
    |> assign(:draft, "")
    |> assign(:code_mode, false)
    |> assign(:typing_users, %{})
  end

  defp load_sidebar(socket) do
    user = socket.assigns.current_user
    channels = Chat.list_channels_for_user(user.id)
    conversations = Chat.list_conversations_for_user(user.id)
    channel_unread = Enum.sum(Enum.map(channels, & &1.unread_count))
    dm_unread = Enum.sum(Enum.map(conversations, & &1.unread_count))

    socket
    |> assign(:channels, channels)
    |> assign(:conversations, conversations)
    |> assign(:unread_mentions, Chat.unread_mention_count(user.id))
    |> assign(:channel_unread_total, channel_unread)
    |> assign(:dm_unread_total, dm_unread)
    |> assign(:chat_unread_count, channel_unread + dm_unread)
  end

  defp reset_channel_form(socket) do
    assign(socket, :channel_changeset, Chat.change_channel(%Channel{}))
  end

  defp load_pinned_messages(socket) do
    pinned =
      cond do
        socket.assigns.active_channel ->
          Chat.list_pinned_channel_messages(socket.assigns.active_channel.id)

        socket.assigns.active_conversation ->
          Chat.list_pinned_conversation_messages(socket.assigns.active_conversation.id)

        true ->
          []
      end

    assign(socket, :pinned_messages, pinned)
  end

  defp maybe_push_initial_chat_notify(socket) do
    if connected?(socket) do
      push_event(socket, "chat:notify", %{
        unread_count: socket.assigns.chat_unread_count,
        initial: true
      })
    else
      socket
    end
  end

  defp active_chat_key(%{id: id}, _conversation), do: "channel-#{id}"
  defp active_chat_key(nil, %{id: id}), do: "dm-#{id}"
  defp active_chat_key(_, _), do: "none"

  defp dm_label(nil, _current_user), do: "DM"

  defp dm_label(%{memberships: memberships} = _conv, current_user)
       when is_list(memberships) do
    other =
      Enum.find(memberships, fn m ->
        m.user_id != current_user.id
      end)

    case other do
      %{user: user} -> user.name || user.email
      _ -> "DM"
    end
  end

  defp dm_label(_conv, _current_user), do: "DM"

  defp user_display_name(nil), do: "Unknown"
  defp user_display_name(%{name: name}) when is_binary(name) and name != "", do: name
  defp user_display_name(%{email: email}), do: email
  defp user_display_name(_), do: "Unknown"

  defp format_time(%DateTime{} = dt) do
    dt
    |> DateTime.add(@kenya_offset_seconds, :second)
    |> Calendar.strftime("%d %b %H:%M EAT")
  end

  defp format_time(_), do: ""

  defp compose_placeholder(%Channel{name: name}, _), do: "Message ##{name}"
  defp compose_placeholder(_, _), do: "Message..."

  defp panel_tab_class(true) do
    "flex-1 rounded-md bg-white shadow-sm py-1.5 text-sm font-semibold text-[#f26334] text-center"
  end

  defp panel_tab_class(false) do
    "flex-1 rounded-md py-1.5 text-sm font-medium text-neutral-500 text-center hover:bg-white/70 hover:text-neutral-800"
  end

  defp sidebar_item_class(is_active, unread?)

  defp sidebar_item_class(true, _) do
    "flex items-center rounded-md px-2 py-1.5 text-sm font-semibold text-[#d9532a] bg-[#f26334]/10 border border-[#f26334]/20"
  end

  defp sidebar_item_class(nil, unread?), do: sidebar_item_class(false, unread?)

  defp sidebar_item_class(false, true) do
    "flex items-center rounded-md px-2 py-1.5 text-sm font-semibold text-neutral-900 hover:bg-white/70"
  end

  defp sidebar_item_class(false, false) do
    "flex items-center rounded-md px-2 py-1.5 text-sm font-medium text-neutral-600 hover:bg-white/70 hover:text-neutral-900"
  end

  defp with_headers([]), do: []

  defp with_headers([first | rest]) do
    {pairs, _} =
      Enum.map_reduce(rest, first, fn msg, prev ->
        same_user = msg.user_id == prev.user_id
        close_time = DateTime.diff(msg.inserted_at, prev.inserted_at, :second) < 300
        show_header = !(same_user && close_time)
        {{msg, show_header}, msg}
      end)

    [{first, true} | pairs]
  end

  defp dm_other_user(%{memberships: memberships}, current_user) when is_list(memberships) do
    case Enum.find(memberships, fn m -> m.user_id != current_user.id end) do
      %{user: user} -> user
      _ -> nil
    end
  end

  defp dm_other_user(_, _), do: nil

  defp load_mention_users do
    everyone = %{id: "all", name: "Everyone"}

    users =
      Accounts.list_users()
      |> Enum.map(&%{id: &1.id, name: &1.name || &1.email})

    [everyone | users]
  end

  defp track_chat_presence(socket) do
    topic = active_presence_topic(socket)
    previous_topic = socket.assigns.presence_topic

    if connected?(socket) && topic && topic != previous_topic do
      if previous_topic,
        do: Presence.untrack(self(), previous_topic, socket.assigns.current_user.id)

      user = socket.assigns.current_user

      Presence.track(self(), topic, user.id, %{
        name: user_display_name(user),
        online_at: DateTime.utc_now() |> DateTime.to_iso8601()
      })
    end

    socket
    |> assign(:presence_topic, topic)
    |> assign(:online_users, list_online_users(topic))
    |> assign(:typing_users, %{})
  end

  defp subscribe_active_chat_topic(socket, topic) do
    previous_topic = socket.assigns.subscribed_chat_topic

    if connected?(socket) && topic != previous_topic do
      if previous_topic, do: Chat.unsubscribe_topic(previous_topic)
      Chat.subscribe_topic(topic)
    end

    assign(socket, :subscribed_chat_topic, topic)
  end

  defp active_presence_topic(%{assigns: %{active_channel: %{id: id}}}) when not is_nil(id),
    do: Chat.channel_presence_topic(id)

  defp active_presence_topic(%{assigns: %{active_conversation: %{id: id}}}) when not is_nil(id),
    do: Chat.conversation_presence_topic(id)

  defp active_presence_topic(_socket), do: nil

  defp list_online_users(nil), do: []

  defp list_online_users(topic) do
    topic
    |> Presence.list()
    |> Enum.map(fn {id, %{metas: metas}} ->
      meta = List.first(metas) || %{}
      %{id: to_integer(id), name: meta[:name] || meta["name"] || "Online user"}
    end)
    |> Enum.sort_by(&String.downcase(&1.name || ""))
  end

  defp online_count(users) do
    users
    |> Enum.reject(&(&1.id == nil))
    |> length()
  end

  defp online_user?(nil, _online_users), do: false
  defp online_user?(%{id: id}, online_users), do: Enum.any?(online_users, &(&1.id == id))

  defp typing_label(typing_users) when map_size(typing_users) == 0, do: nil

  defp typing_label(typing_users) do
    names =
      typing_users
      |> Map.values()
      |> Enum.map(& &1.name)
      |> Enum.uniq()
      |> Enum.take(3)

    case names do
      [name] -> "#{name} is typing..."
      [first, second] -> "#{first} and #{second} are typing..."
      [_first, _second, _third] -> "Several people are typing..."
      _ -> nil
    end
  end

  defp clear_typing_user(socket, nil), do: socket

  defp clear_typing_user(socket, user_id) do
    update(socket, :typing_users, &Map.delete(&1, user_id))
  end

  defp clear_typing_user(socket, user_id, expires_at) do
    update(socket, :typing_users, fn users ->
      case Map.get(users, user_id) do
        %{expires_at: ^expires_at} -> Map.delete(users, user_id)
        _ -> users
      end
    end)
  end

  defp append_message_once(socket, message) do
    if active_message?(socket, message) do
      update(socket, :messages, fn messages ->
        if Enum.any?(messages, &(&1.id == message.id)) do
          messages
        else
          messages ++ [message]
        end
      end)
    else
      socket
    end
  end

  defp active_message?(socket, %{channel_id: channel_id}) when not is_nil(channel_id) do
    socket.assigns.active_channel && socket.assigns.active_channel.id == channel_id
  end

  defp active_message?(socket, %{conversation_id: conversation_id})
       when not is_nil(conversation_id) do
    socket.assigns.active_conversation && socket.assigns.active_conversation.id == conversation_id
  end

  defp active_message?(_socket, _message), do: false

  defp to_integer(value) when is_integer(value), do: value

  defp to_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _ -> nil
    end
  end

  defp render_message_body(body, current_user_id) when is_binary(body) do
    body
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
    |> link_urls()
    |> render_mentions(current_user_id)
    |> render_markdown_images()
    |> Phoenix.HTML.raw()
  end

  defp render_message_body(body, _), do: body

  defp link_urls(body) do
    Regex.replace(@url_regex, body, fn url ->
      {href, trailing} = trim_trailing_url_punctuation(url)

      ~s(<a href="#{href}" target="_blank" rel="noopener noreferrer" class="font-medium text-[#f26334] underline underline-offset-2 hover:text-[#d9532a]">#{href}</a>#{trailing})
    end)
  end

  defp trim_trailing_url_punctuation(url) do
    case Regex.run(~r/^(.+?)([.,!?;:)]+)?$/, url) do
      [_, href, trailing] when trailing not in [nil, ""] -> {href, trailing}
      _ -> {url, ""}
    end
  end

  defp render_mentions(body, current_user_id) do
    Regex.replace(@mention_regex, body, fn _, name, uid_str ->
      if String.to_integer(uid_str) == current_user_id do
        "<span class=\"rounded bg-amber-100 px-1 font-medium text-amber-800\">@#{name}</span>"
      else
        "<span class=\"font-medium text-[#f26334]\">@#{name}</span>"
      end
    end)
  end

  defp render_markdown_images(body) do
    Regex.replace(@markdown_image_regex, body, fn _, alt, url ->
      """
      <figure class="my-2 overflow-hidden rounded-md border border-neutral-200 bg-white">
        <img src="#{url}" alt="#{alt}" loading="lazy" class="max-h-72 w-full object-contain" />
        <figcaption class="truncate px-3 py-2 text-xs text-neutral-500">#{alt}</figcaption>
      </figure>
      """
    end)
  end

  defp grouped_reactions(reactions) do
    reactions
    |> Enum.group_by(& &1.emoji)
    |> Enum.map(fn {emoji, grouped} ->
      {emoji, %{count: length(grouped), user_ids: Enum.map(grouped, & &1.user_id)}}
    end)
    |> Enum.sort_by(fn {emoji, _reaction} -> emoji end)
  end

  defp reacted?(grouped_reactions, emoji, user_id) when is_list(grouped_reactions) do
    case List.keyfind(grouped_reactions, emoji, 0) do
      {_, reaction} -> reacted?(reaction, user_id)
      nil -> false
    end
  end

  defp reacted?(%{user_ids: user_ids}, user_id), do: user_id in user_ids

  defp mark_active_message_read(socket, %{channel_id: channel_id}) when not is_nil(channel_id) do
    if socket.assigns.active_channel && socket.assigns.active_channel.id == channel_id do
      Chat.mark_channel_read(channel_id, socket.assigns.current_user.id)
    end

    socket
  end

  defp mark_active_message_read(socket, %{conversation_id: conversation_id})
       when not is_nil(conversation_id) do
    if socket.assigns.active_conversation &&
         socket.assigns.active_conversation.id == conversation_id do
      Chat.mark_conversation_read(conversation_id, socket.assigns.current_user.id)
    end

    socket
  end

  defp mark_active_message_read(socket, _message), do: socket

  defp upload_error_msg(:too_large), do: "File too large (max 25 MB)"
  defp upload_error_msg(:not_accepted), do: "File type not allowed"
  defp upload_error_msg(:too_many_files), do: "Too many files (max 6)"
  defp upload_error_msg(_), do: "Upload error"

  defp attachment_type(client_type) do
    cond do
      String.starts_with?(client_type, "image/") -> "image"
      String.starts_with?(client_type, "video/") -> "video"
      true -> "file"
    end
  end
end
