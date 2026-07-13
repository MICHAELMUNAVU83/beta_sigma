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

  embed_templates "layouts/*"

  def chat_title_prefix(assigns) do
    case assigns[:chat_unread_count] do
      count when is_integer(count) and count > 0 -> "(#{count}) "
      _other -> ""
    end
  end
end
