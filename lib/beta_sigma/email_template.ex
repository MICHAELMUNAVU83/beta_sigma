# credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
# credo:disable-for-this-file Credo.Check.Refactor.Nesting
defmodule BetaSigma.EmailTemplate do
  @moduledoc false

  @brand_name "BetaSigma"

  # ── Email theme ────────────────────────────────────────────────────────────
  # Change these to restyle all outgoing emails from one place.

  # Backgrounds
  @color_shell "#f5f5f5"
  @color_card "#ffffff"
  @color_details_bg "#fafafa"

  # Text
  @color_text "#171717"
  @color_muted "#525252"
  @color_fallback_note "#737373"

  # Brand / interactive
  @color_brand "#171717"

  # Borders
  @color_border "#e5e5e5"

  # Radii
  @radius_card "8px"
  @radius_button "6px"
  @radius_details "6px"
  # ── End theme ──────────────────────────────────────────────────────────────

  def render_html(message) when is_map(message) do
    preheader =
      presence(message[:preheader]) || presence(message[:intro]) || message[:subject] ||
        @brand_name

    eyebrow = presence(message[:eyebrow])
    title = presence(message[:title]) || message[:subject] || @brand_name
    intro_html = paragraphs_html(message[:intro])
    body_html = paragraphs_html(message[:body])
    details_html = details_html(message[:details] || [])
    cta_html = cta_html(message[:cta], message[:secondary_cta])
    footer_note = presence(message[:footer_note]) || "This message was sent by #{@brand_name}."
    show_sign_off = message[:sign_off] != false

    """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <meta name="x-apple-disable-message-reformatting" />
        <meta name="color-scheme" content="light" />
        <meta name="supported-color-schemes" content="light" />
        <link href="https://fonts.googleapis.com/css2?family=Roboto:wght@400;500;700&display=swap" rel="stylesheet">
        <title>#{escape_html(title)}</title>
        <style>
          :root {
            color-scheme: light;
            supported-color-schemes: light;
          }
        </style>
      </head>
      <body style="margin:0; padding:0; background-color:#{@color_shell}; font-family:'Roboto', -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Helvetica', sans-serif; color:#{@color_text};">
        <div style="display:none; max-height:0; overflow:hidden; opacity:0; mso-hide:all;">
          #{escape_html(preheader)}
        </div>

        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" bgcolor="#{@color_shell}" style="background-color:#{@color_shell}; padding:40px 20px;">
          <tr>
            <td align="center">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:600px; margin:0 auto;">
                <tr>
                  <td>
                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" bgcolor="#{@color_card}" style="background-color:#{@color_card}; border-radius:#{@radius_card}; overflow:hidden; box-shadow:0 1px 3px rgba(0,0,0,0.05);">

                      <!-- Header -->
                      <tr>
                        <td style="padding:48px 40px 32px 40px;">
                          #{if presence(eyebrow) do
      ~s(<div style="font-size:12px; font-weight:500; color:#{@color_muted}; margin-bottom:12px;">#{escape_html(eyebrow)}</div>)
    else
      ""
    end}
                          <h1 style="margin:0; font-size:24px; font-weight:600; color:#{@color_text}; line-height:1.3;">
                            #{escape_html(title)}
                          </h1>
                        </td>
                      </tr>

                      <!-- Body -->
                      <tr>
                        <td style="padding:0 40px;">
                          <div style="font-size:16px; line-height:1.6; color:#{@color_text};">
                            #{intro_html}
                          </div>
                          <div style="font-size:16px; line-height:1.6; color:#{@color_text};">
                            #{body_html}
                          </div>
                          #{details_html}
                          #{cta_html}
                        </td>
                      </tr>

                      <!-- Sign-off -->
                      #{if show_sign_off do
      """
      <tr>
        <td style="padding:32px 40px 48px 40px;">
          <p style="margin:0; font-size:16px; color:#{@color_text}; line-height:1.6;">Best regards,</p>
          <p style="margin:8px 0 0 0; font-size:16px; color:#{@color_text}; line-height:1.6;">
            <strong>#{@brand_name}</strong><br>
            <a href="mailto:hello@vumbuzi-ai.co.ke" style="color:#{@color_muted}; text-decoration:none; font-size:14px;">hello@vumbuzi-ai.co.ke</a>
          </p>
        </td>
      </tr>
      """
    else
      ~s(<tr><td style="padding:0 0 24px 0;"></td></tr>)
    end}

                    </table>

                    <div style="padding:18px 12px 0; font-size:12px; line-height:1.7; color:#{@color_muted}; text-align:center;">
                      #{escape_html(footer_note)}
                    </div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      </body>
    </html>
    """
  end

  def render_text(message) when is_map(message) do
    parts = [
      presence(message[:eyebrow]) || @brand_name,
      presence(message[:title]) || message[:subject],
      paragraphs_text(message[:intro]),
      details_text(message[:details] || []),
      paragraphs_text(message[:body]),
      cta_text(message[:cta], message[:secondary_cta]),
      presence(message[:footer_note]) || "This message was sent by #{@brand_name}."
    ]

    parts
    |> Enum.reject(&blank?/1)
    |> Enum.join("\n\n")
  end

  defp paragraphs_html(nil), do: ""

  defp paragraphs_html(content) do
    content
    |> normalize_paragraphs()
    |> Enum.map_join(fn paragraph ->
      escaped = paragraph |> escape_html() |> String.replace("\n", "<br />")

      ~s(<p style="margin:0 0 16px 0; font-size:16px; color:#{@color_text}; line-height:1.6;">#{escaped}</p>)
    end)
  end

  defp paragraphs_text(nil), do: nil

  defp paragraphs_text(content) do
    content
    |> normalize_paragraphs()
    |> Enum.join("\n\n")
  end

  defp details_html([]), do: ""

  defp details_html(details) do
    rows =
      details
      |> normalize_details()
      |> Enum.map_join(fn {label, value} ->
        """
        <tr>
          <td style="padding:14px 16px 4px 16px; border-top:1px solid #{@color_border}; font-size:11px; font-weight:500; color:#{@color_muted};">
            #{escape_html(label)}
          </td>
        </tr>
        <tr>
          <td style="padding:0 16px 14px 16px; font-size:14px; line-height:1.7; color:#{@color_text};">
            #{escape_html(value)}
          </td>
        </tr>
        """
      end)

    if rows == "" do
      ""
    else
      """
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" bgcolor="#{@color_details_bg}" style="margin-top:24px; border:1px solid #{@color_border}; border-radius:#{@radius_details}; overflow:hidden; background-color:#{@color_details_bg};">
        #{rows}
      </table>
      """
    end
  end

  defp details_text(details) do
    details
    |> normalize_details()
    |> Enum.map_join("\n", fn {label, value} -> "#{label}: #{value}" end)
    |> presence()
  end

  defp cta_html(primary_cta, secondary_cta) do
    ctas =
      [normalize_cta(primary_cta, :primary), normalize_cta(secondary_cta, :secondary)]
      |> Enum.reject(&is_nil/1)

    if ctas == [] do
      ""
    else
      buttons =
        ctas
        |> Enum.map_join(&cta_button_html/1)

      fallback_links =
        ctas
        |> Enum.map_join(&cta_fallback_html/1)

      """
      <div style="margin-top:28px;">
        #{buttons}
        <div style="margin-top:16px; font-size:13px; line-height:1.8; color:#{@color_fallback_note};">
          If the button does not open, copy and paste this link into your browser:
          #{fallback_links}
        </div>
      </div>
      """
    end
  end

  defp cta_text(primary_cta, secondary_cta) do
    [normalize_cta(primary_cta, :primary), normalize_cta(secondary_cta, :secondary)]
    |> Enum.reject(&is_nil/1)
    |> Enum.map_join("\n", fn %{label: label, url: url} -> "#{label}: #{url}" end)
    |> presence()
  end

  defp cta_button_html(%{label: label, url: url, variant: :primary}) do
    """
    <a href="#{escape_html(url)}" style="display:inline-block; margin-right:12px; margin-bottom:12px; padding:12px 24px; border-radius:#{@radius_button}; background-color:#{@color_brand}; color:#ffffff; font-size:15px; font-weight:500; text-decoration:none;">
      #{escape_html(label)}
    </a>
    """
  end

  defp cta_button_html(%{label: label, url: url, variant: :secondary}) do
    """
    <a href="#{escape_html(url)}" style="display:inline-block; margin-right:12px; margin-bottom:12px; padding:12px 24px; border-radius:#{@radius_button}; background-color:#{@color_card}; color:#{@color_text}; font-size:15px; font-weight:500; text-decoration:none; border:1px solid #{@color_text};">
      #{escape_html(label)}
    </a>
    """
  end

  defp cta_fallback_html(%{label: label, url: url}) do
    """
    <div style="margin-top:10px;">
      #{escape_html(label)}:<br />
      <a href="#{escape_html(url)}" style="color:#{@color_brand}; text-decoration:underline; word-break:break-all;">
        #{escape_html(url)}
      </a>
    </div>
    """
  end

  defp normalize_cta(nil, _variant), do: nil

  defp normalize_cta(%{label: label, url: url}, variant) do
    %{label: to_string(label), url: to_string(url), variant: variant}
  end

  defp normalize_cta(_cta, _variant), do: nil

  defp normalize_paragraphs(content) when is_binary(content) do
    content
    |> String.trim()
    |> String.split(~r/\n\s*\n/, trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_paragraphs(content) when is_list(content) do
    content
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_paragraphs(_content), do: []

  defp normalize_details(details) do
    details
    |> Enum.map(fn
      {label, value} -> {to_string(label), to_string(value)}
      %{label: label, value: value} -> {to_string(label), to_string(value)}
    end)
    |> Enum.reject(fn {label, value} -> blank?(label) or blank?(value) end)
  end

  defp escape_html(value) do
    value
    |> to_string()
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  defp presence(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp presence(value), do: value

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_value), do: false
end
