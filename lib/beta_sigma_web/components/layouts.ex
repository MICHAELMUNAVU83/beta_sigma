defmodule BetaSigmaWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use BetaSigmaWeb, :controller` and
  `use BetaSigmaWeb, :live_view`.
  """
  use BetaSigmaWeb, :html

  import BetaSigmaWeb.MarketingComponents

  embed_templates "layouts/*"

  def chat_title_prefix(assigns) do
    case assigns[:chat_unread_count] do
      count when is_integer(count) and count > 0 -> "(#{count}) "
      _other -> ""
    end
  end

  def meta_description(assigns) do
    assigns[:meta_description] ||
      "BeCorp is a diversified investment and operating company that builds, scales and manages high-growth industries across strategic sectors in Africa."
  end
end
