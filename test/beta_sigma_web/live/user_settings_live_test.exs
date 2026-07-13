defmodule BetaSigmaWeb.UserSettingsLiveTest do
  use BetaSigmaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import BetaSigma.AccountsFixtures

  alias BetaSigma.Accounts

  test "server-side avatar upload fallback works", %{conn: conn} do
    user = user_fixture()

    jpeg =
      [
        <<0xFF, 0xD8>>,
        <<0xFF, 0xE0, 0x00, 0x10, "JFIF\0", 0x01, 0x02, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
          0x00>>,
        <<0xFF, 0xC0, 0x00, 0x11, 0x08, 0x00, 0x80, 0x00, 0x80, 0x03, 0x01, 0x22, 0x00, 0x02,
          0x11, 0x01, 0x03, 0x11, 0x01>>,
        <<0xFF, 0xD9>>
      ]
      |> IO.iodata_to_binary()

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/users/settings")

    avatar =
      file_input(view, "#avatar-form", :avatar, [
        %{
          name: "avatar.jpg",
          content: jpeg,
          size: byte_size(jpeg),
          type: "image/jpeg"
        }
      ])

    assert render_upload(avatar, "avatar.jpg") =~ "100%"

    html =
      view
      |> form("#avatar-form")
      |> render_submit()

    assert html =~ "Profile picture updated."

    uploaded_user = Accounts.get_user!(user.id)
    assert uploaded_user.avatar_url =~ "/uploads/avatars/"
    assert uploaded_user.avatar_url =~ ".jpg"
  end

  test "server-side avatar upload failure shows an error", %{conn: conn} do
    user = user_fixture()

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/users/settings")

    avatar =
      file_input(view, "#avatar-form", :avatar, [
        %{
          name: "avatar.jpg",
          content: "not an image",
          size: 12,
          type: "image/jpeg"
        }
      ])

    assert render_upload(avatar, "avatar.jpg") =~ "100%"

    html =
      view
      |> form("#avatar-form")
      |> render_submit()

    assert html =~ "The selected image could not be processed."

    uploaded_user = Accounts.get_user!(user.id)
    assert uploaded_user.avatar_url == user.avatar_url
  end

  test "client-side avatar data URL upload works", %{conn: conn} do
    user = user_fixture()

    jpeg =
      [
        <<0xFF, 0xD8>>,
        <<0xFF, 0xE0, 0x00, 0x10, "JFIF\0", 0x01, 0x02, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
          0x00>>,
        <<0xFF, 0xC0, 0x00, 0x11, 0x08, 0x00, 0x80, 0x00, 0x80, 0x03, 0x01, 0x22, 0x00, 0x02,
          0x11, 0x01, 0x03, 0x11, 0x01>>,
        <<0xFF, 0xD9>>
      ]
      |> IO.iodata_to_binary()

    data_url = "data:image/jpeg;base64," <> Base.encode64(jpeg)

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/users/settings")

    html =
      render_submit(view, :save_avatar_from_client, %{
        avatar_data_url: data_url,
        filename: "avatar.jpg"
      })

    assert html =~ "Profile picture updated."

    uploaded_user = BetaSigma.Accounts.get_user!(user.id)
    assert uploaded_user.avatar_url =~ "/uploads/avatars/"
    assert uploaded_user.avatar_url =~ ".jpg"
  end
end
