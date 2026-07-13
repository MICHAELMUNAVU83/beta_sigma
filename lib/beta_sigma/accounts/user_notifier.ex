defmodule BetaSigma.Accounts.UserNotifier do
  @moduledoc false

  alias BetaSigma.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, attrs) do
    email =
      attrs
      |> Map.merge(%{
        to: recipient,
        subject: subject,
        eyebrow: "Account security"
      })

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, %{to: recipient, subject: subject}}
    end
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions", %{
      preheader: "Confirm your BetaSigma account email.",
      title: "Confirm your account",
      intro:
        "Hi #{display_name(user)}, confirm your email to finish setting up your BetaSigma account.",
      body: [
        "Use the secure button below to confirm that #{user.email} belongs to you.",
        "If you did not create an account with us, you can ignore this email."
      ],
      details: [{"Account email", user.email}],
      cta: %{label: "Confirm account", url: url},
      footer_note: "For security, confirmation links expire automatically after a limited time."
    })
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    deliver(user.email, "Reset password instructions", %{
      preheader: "Reset your BetaSigma password securely.",
      title: "Reset your password",
      intro:
        "Hi #{display_name(user)}, we received a request to reset the password for your account.",
      body: [
        "Use the secure button below to choose a new password.",
        "If you did not request this change, you can ignore this email and your current password will remain active."
      ],
      details: [{"Account email", user.email}],
      cta: %{label: "Reset password", url: url},
      footer_note: "For security, reset links are time-limited and should not be shared."
    })
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Update email instructions", %{
      preheader: "Approve your BetaSigma email address change.",
      title: "Confirm your new email",
      intro:
        "Hi #{display_name(user)}, we received a request to update the email address on your BetaSigma account.",
      body: [
        "Use the secure button below to approve the new address before the change is applied.",
        "If you did not request this update, you can ignore this email and the current address will remain unchanged."
      ],
      details: [{"Current account email", user.email}],
      cta: %{label: "Confirm new email", url: url},
      footer_note: "For security, email-change links expire automatically after a limited time."
    })
  end

  defp display_name(%{name: name, email: email}) do
    case String.trim(name || "") do
      "" -> email
      trimmed -> trimmed
    end
  end
end
