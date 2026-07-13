defmodule BetaSigma.Projects.Mentions do
  @moduledoc """
  Parsing and rendering of `@[Name](user:ID)` mention tokens, plus a tiny
  markdown-lite syntax (`**bold**` and `# Heading`) for free-text fields such
  as task and project descriptions.

  Mentions are embedded directly in free-text fields using a stable token so
  they can be diffed across edits and rendered without re-resolving names
  against the database.
  """

  @token_regex ~r/@\[([^\]\n]+)\]\(user:(\d+)\)/
  @bold_regex ~r/\*\*([^\n]+?)\*\*/
  @heading_regex ~r/^(\#{1,3})\s+(.*)$/
  @image_regex ~r/^!\[([^\]\n]*)\]\(([^)\n]+)\)$/

  @doc "Returns the unique user ids referenced by mention tokens in `text`."
  def extract_user_ids(text) when is_binary(text) do
    @token_regex
    |> Regex.scan(text)
    |> Enum.map(fn [_full, _name, id] -> String.to_integer(id) end)
    |> Enum.uniq()
  end

  def extract_user_ids(_text), do: []

  @doc """
  Splits `text` into an ordered list of segments for safe rendering:

      [{:text, "Ping "}, {:mention, "Jane Doe"}, {:text, " to review"}]

  Lines starting with `#`, `##`, or `###` become `{:heading, level, segments}`
  entries, where `segments` is the inline (mention/bold/text) breakdown of the
  rest of that line. Other lines yield inline segments directly, separated by
  `{:newline}` markers.
  """
  def to_segments(text) when is_binary(text) do
    text
    |> String.split("\n")
    |> Enum.map(&line_to_segment/1)
    |> Enum.intersperse({:newline})
  end

  def to_segments(_text), do: []

  defp line_to_segment(line) do
    cond do
      match = Regex.run(@image_regex, line) ->
        [_full, alt, url] = match
        {:image, alt, url}

      match = Regex.run(@heading_regex, line) ->
        [_full, marks, rest] = match
        {:heading, String.length(marks), inline_segments(rest)}

      true ->
        {:line, inline_segments(line)}
    end
  end

  defp inline_segments(text) do
    @token_regex
    |> Regex.split(text, include_captures: true)
    |> Enum.reject(&(&1 == ""))
    |> Enum.flat_map(fn part ->
      case Regex.run(@token_regex, part) do
        [_full, name, _id] -> [{:mention, name}]
        _ -> bold_segments(part)
      end
    end)
  end

  defp bold_segments(text) do
    @bold_regex
    |> Regex.split(text, include_captures: true)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn part ->
      case Regex.run(@bold_regex, part) do
        [_full, bold_text] -> {:bold, bold_text}
        _ -> {:text, part}
      end
    end)
  end
end
