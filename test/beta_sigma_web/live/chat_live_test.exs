defmodule BetaSigmaWeb.ChatLiveTest do
  use BetaSigmaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import BetaSigma.AccountsFixtures

  alias BetaSigma.Chat

  test "renders message links as anchors while escaping other HTML", %{conn: conn} do
    user = admin_fixture()

    {:ok, channel} = Chat.create_channel(user, %{"name" => "General", "kind" => "public"})

    {:ok, _message} =
      Chat.send_channel_message(
        channel.id,
        user,
        "Open https://example.com/docs <script>alert(1)</script>"
      )

    {:ok, _view, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/app/chat?channel=#{channel.id}")

    assert html =~ ~s(href="https://example.com/docs")
    assert html =~ ~s(target="_blank")
    assert html =~ "&lt;script&gt;alert(1)&lt;/script&gt;"
    refute html =~ "<script>alert(1)</script>"
  end

  test "toggles emoji reactions from the chat message list", %{conn: conn} do
    user = admin_fixture()
    {:ok, channel} = Chat.create_channel(user, %{"name" => "General", "kind" => "public"})
    {:ok, message} = Chat.send_channel_message(channel.id, user, "Ship it 🚀")

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/app/chat?channel=#{channel.id}")

    html =
      view
      |> element("#msg-#{message.id} button[phx-value-emoji='👍']")
      |> render_click()

    assert html =~ "Ship it 🚀"
    assert html =~ "👍 1"

    html =
      view
      |> element("#msg-#{message.id} button[phx-value-emoji='👍']")
      |> render_click()

    refute html =~ "👍 1"
  end

  test "does not render duplicate message events twice", %{conn: conn} do
    user = admin_fixture()
    {:ok, channel} = Chat.create_channel(user, %{"name" => "General", "kind" => "public"})

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/app/chat?channel=#{channel.id}")

    {:ok, message} = Chat.send_channel_message(channel.id, user, "Only once")

    send(view.pid, %{event: :message_created, message: message})
    html = render(view)

    assert html =~ "Only once"
    assert html |> occurrences("Only once") == 1
  end

  defp occurrences(text, value) do
    text
    |> String.split(value)
    |> length()
    |> Kernel.-(1)
  end
end
