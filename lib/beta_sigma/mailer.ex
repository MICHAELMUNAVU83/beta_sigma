defmodule BetaSigma.Mailer do
  @moduledoc false

  require Logger

  alias BetaSigma.{EmailTemplate, Resend}

  def deliver(message) when is_map(message) do
    payload = %{
      to: Map.fetch!(message, :to),
      subject: Map.fetch!(message, :subject),
      cc: Map.get(message, :cc, []),
      attachments: Map.get(message, :attachments, []),
      html_body: Map.get(message, :html_body) || EmailTemplate.render_html(message),
      text_body: Map.get(message, :text_body) || EmailTemplate.render_text(message)
    }

    payload =
      payload
      |> maybe_put(:from_email, message[:from_email])
      |> maybe_put(:from_name, message[:from_name])

    case delivery_mode() do
      :noop ->
        {:ok, Map.put(payload, :delivery_mode, :noop)}

      :resend ->
        Resend.deliver(payload)

      other ->
        Logger.warning("Unknown mailer delivery_mode=#{inspect(other)}; using :resend")
        Resend.deliver(payload)
    end
  end

  defp delivery_mode do
    case System.get_env("MAILER_DELIVERY_MODE") do
      "gmail" ->
        Logger.warning("MAILER_DELIVERY_MODE=gmail is deprecated; using resend instead")
        :resend

      "resend" ->
        :resend

      "noop" ->
        :noop

      nil ->
        configured_delivery_mode()

      _other ->
        configured_delivery_mode()
    end
  end

  defp configured_delivery_mode do
    configured =
      :beta_sigma
      |> Application.get_env(__MODULE__, [])
      |> Keyword.get(:delivery_mode, :resend)

    case configured do
      :noop ->
        :noop

      :resend ->
        :resend

      :gmail ->
        Logger.warning(
          "Configured mailer delivery_mode=:gmail is deprecated; using :resend instead"
        )

        :resend

      other ->
        Logger.warning(
          "Configured mailer delivery_mode=#{inspect(other)} is invalid; using :resend instead"
        )

        :resend
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
