defmodule BetaSigmaWeb.AdminUsersLiveTest do
  use BetaSigmaWeb.ConnCase, async: true

  import BetaSigma.AccountsFixtures
  import Phoenix.LiveViewTest

  alias BetaSigma.Accounts

  test "an admin can permanently delete another user", %{conn: conn} do
    admin = admin_fixture()
    user = user_fixture(%{email: "delete-me@example.com"})

    {:ok, view, html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/admin/users")

    assert html =~ "delete-me@example.com"

    view
    |> element("button[phx-click=delete_user][phx-value-id='#{user.id}']")
    |> render_click()

    refute Accounts.get_user_by_email("delete-me@example.com")
    assert render(view) =~ "delete-me@example.com was permanently deleted."
  end

  test "an admin cannot delete their own account", %{conn: conn} do
    admin = admin_fixture()

    {:ok, view, _html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/admin/users")

    refute has_element?(view, "button[phx-click=delete_user][phx-value-id='#{admin.id}']")

    assert render_click(view, "delete_user", %{"id" => to_string(admin.id)}) =~
             "You cannot delete your own account."

    assert Accounts.get_user!(admin.id)
  end
end
