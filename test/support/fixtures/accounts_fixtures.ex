defmodule BetaSigma.AccountsFixtures do
  @moduledoc false

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"
  def valid_user_name, do: "Test User"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: valid_user_name(),
      email: unique_user_email(),
      password: valid_user_password()
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> BetaSigma.Accounts.register_user()

    user
  end

  def admin_fixture(attrs \\ %{}) do
    user = user_fixture(attrs)
    {:ok, user} = BetaSigma.Accounts.update_user_role(user, :admin)
    user
  end
end
