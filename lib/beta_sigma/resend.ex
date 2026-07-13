defmodule BetaSigma.Resend do
  @moduledoc false

  require Logger

  @api_url "https://api.resend.com/emails"
  @default_from_email "noreply@vumbuzi-ai.co.ke"
  @default_from_name "BetaSigma"

  def deliver(message) when is_map(message) do
    api_key = api_key()

    if !is_binary(api_key) or String.trim(api_key) == "" do
      Logger.error("Missing RESEND_API_KEY; cannot deliver email via Resend")
      {:error, :missing_resend_api_key}
    else
      payload =
        %{
          "from" => from_header(message),
          "to" => normalize_recipients(Map.fetch!(message, :to)),
          "subject" => Map.fetch!(message, :subject),
          "html" => Map.get(message, :html_body, ""),
          "text" => Map.get(message, :text_body, "")
        }
        |> maybe_put("cc", normalize_optional_recipients(Map.get(message, :cc, [])))
        |> maybe_put("attachments", normalize_attachments(Map.get(message, :attachments, [])))

      req_options = [
        headers: headers(api_key),
        json: payload,
        retry: :transient,
        max_retries: 5,
        receive_timeout: 60_000
      ]

      case Req.post(@api_url, req_options) do
        {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
          {:ok, %{request: payload, status: status, response_body: body}}

        {:ok, %Req.Response{status: status, body: body}} ->
          {:error, {:resend_request_failed, status, body}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  def send(email, subject, body) when is_binary(email) and is_binary(subject) do
    deliver(%{
      to: email,
      subject: subject,
      html_body: body,
      text_body: body |> to_string() |> strip_html()
    })
  end

  defp headers(api_key) do
    [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]
  end

  defp api_key do
    "re_GwmjQs1j_7C5zLo2m8mwstxc3cmjpLuJ8"
  end

  defp from_header(message) do
    email =
      message
      |> Map.get(:from_email)
      |> present_or(@default_from_email)

    name =
      message
      |> Map.get(:from_name)
      |> present_or(@default_from_name)

    "#{name} <#{email}>"
  end

  defp normalize_recipients(recipients) when is_binary(recipients), do: [String.trim(recipients)]

  defp normalize_recipients(recipients) when is_list(recipients),
    do: Enum.map(recipients, &String.trim/1)

  defp normalize_recipients(recipients) do
    recipients
    |> List.wrap()
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
  end

  defp normalize_optional_recipients(nil), do: []
  defp normalize_optional_recipients(recipients), do: normalize_recipients(recipients)

  defp normalize_attachments(nil), do: []
  defp normalize_attachments([]), do: []

  defp normalize_attachments(attachments) do
    attachments
    |> List.wrap()
    |> Enum.map(&normalize_attachment/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_attachment(%{filename: filename, content: content})
       when is_binary(filename) and is_binary(content) do
    %{"filename" => filename, "content" => content}
  end

  defp normalize_attachment(%{"filename" => filename, "content" => content})
       when is_binary(filename) and is_binary(content) do
    %{"filename" => filename, "content" => content}
  end

  defp normalize_attachment({filename, content})
       when is_binary(filename) and is_binary(content) do
    %{"filename" => filename, "content" => Base.encode64(content)}
  end

  defp normalize_attachment(file_path) when is_binary(file_path) do
    %{
      "filename" => Path.basename(file_path),
      "content" => file_path |> File.read!() |> Base.encode64()
    }
  end

  defp normalize_attachment(_attachment), do: nil

  defp maybe_put(map, _key, []), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp present_or(nil, fallback), do: fallback
  defp present_or("", fallback), do: fallback

  defp present_or(value, fallback) when is_binary(value) do
    case String.trim(value) do
      "" -> fallback
      trimmed -> trimmed
    end
  end

  defp present_or(_value, fallback), do: fallback

  defp strip_html(body) when is_binary(body) do
    body
    |> String.replace(~r/<br\s*\/?>/i, "\n")
    |> String.replace(~r/<\/p>/i, "\n\n")
    |> String.replace(~r/<[^>]*>/, "")
    |> String.replace("&nbsp;", " ")
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.trim()
  end

  defp strip_html(body), do: body |> to_string() |> strip_html()

end
