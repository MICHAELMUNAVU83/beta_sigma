defmodule BetaSigma.EmailTemplateTest do
  use ExUnit.Case, async: true

  alias BetaSigma.EmailTemplate

  test "renders emails with fallback links and dark-mode-safe contrast" do
    html =
      EmailTemplate.render_html(%{
        subject: "Reset password instructions",
        eyebrow: "Account security",
        title: "Reset your password",
        intro: "We received a request to reset your password.",
        body: [
          "Use the secure button below to choose a new password.",
          "If you did not request this change, you can ignore this email."
        ],
        details: [{"Account email", "michael@example.com"}],
        cta: %{label: "Reset password", url: "https://example.com/reset"},
        footer_note: "Security links expire automatically."
      })

    assert html =~ "name=\"color-scheme\" content=\"light\""
    assert html =~ "supported-color-schemes"
    assert html =~ "background-color:#f7f6f3"
    assert html =~ "background-color:#ffffff"
    assert html =~ "background-color:#f26334"
    assert html =~ "If the button does not open, copy and paste this link into your browser:"
    assert html =~ "https://example.com/reset"
    assert html =~ "BetaSigma"
    assert html =~ "Reset your password"
    assert html =~ "michael@example.com"
    refute html =~ "background:#1f1916"
  end

  test "renders an optional secondary CTA" do
    html =
      EmailTemplate.render_html(%{
        subject: "Interview invite",
        title: "Book your interview",
        cta: %{label: "Book interview", url: "https://example.com/book"},
        secondary_cta: %{label: "View results", url: "https://example.com/results"}
      })

    assert html =~ "Book interview"
    assert html =~ "View results"
    assert html =~ "https://example.com/book"
    assert html =~ "https://example.com/results"
  end
end
