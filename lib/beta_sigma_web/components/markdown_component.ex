defmodule BetaSigmaWeb.MarkdownComponent do
  @moduledoc false

  use Phoenix.Component

  attr :body, :string, required: true
  attr :empty_copy, :string, default: "No content yet."

  def markdown_viewer(assigns) do
    assigns = assign(assigns, :blocks, markdown_blocks(assigns.body))

    ~H"""
    <div class="select-text space-y-4 text-slate-700">
      <p :if={@blocks == []} class="text-sm italic text-slate-400">{@empty_copy}</p>
      <.markdown_block :for={block <- @blocks} block={block} />
    </div>
    """
  end

  def markdown_preview(text, fallback \\ "Open to review the full note.")

  def markdown_preview(text, fallback) when is_binary(text) do
    text
    |> String.split("\n")
    |> Enum.map(&strip_markdown_prefix/1)
    |> Enum.map(&strip_inline_bold_markers/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.take(3)
    |> Enum.join(" ")
    |> case do
      "" -> fallback
      preview -> preview
    end
  end

  def markdown_preview(_text, fallback), do: fallback

  def markdown_title?(title) when is_binary(title), do: String.ends_with?(title, ".md")
  def markdown_title?(_title), do: false

  attr :block, :map, required: true

  defp markdown_block(%{block: %{type: :spacer}} = assigns) do
    ~H"""
    <div class="h-2"></div>
    """
  end

  defp markdown_block(%{block: %{type: :h1, content: content}} = assigns) do
    assigns = assign(assigns, :segments, inline_segments(content))

    ~H"""
    <h1 class="text-3xl font-semibold tracking-tight text-slate-950">
      <.inline_content segments={@segments} />
    </h1>
    """
  end

  defp markdown_block(%{block: %{type: :h2, content: content}} = assigns) do
    assigns = assign(assigns, :segments, inline_segments(content))

    ~H"""
    <div class="border-t border-stone-200 pt-5 first:border-t-0 first:pt-0">
      <h2 class="text-lg font-semibold tracking-tight text-slate-900">
        <.inline_content segments={@segments} />
      </h2>
    </div>
    """
  end

  defp markdown_block(%{block: %{type: :h3, content: content}} = assigns) do
    assigns = assign(assigns, :segments, inline_segments(content))

    ~H"""
    <h3 class="text-xs font-semibold uppercase tracking-[0.18em] text-orange-700">
      <.inline_content segments={@segments} />
    </h3>
    """
  end

  defp markdown_block(%{block: %{type: :bullet, content: content}} = assigns) do
    assigns = assign(assigns, :segments, inline_segments(content))

    ~H"""
    <div class="flex gap-3 text-[15px] leading-7 text-slate-700">
      <span class="mt-[0.72rem] h-1.5 w-1.5 rounded-full bg-orange-400"></span>
      <p class="flex-1"><.inline_content segments={@segments} /></p>
    </div>
    """
  end

  defp markdown_block(%{block: %{type: :paragraph, content: content}} = assigns) do
    assigns = assign(assigns, :segments, inline_segments(content))

    ~H"""
    <p class="text-[15px] leading-7 text-slate-700"><.inline_content segments={@segments} /></p>
    """
  end

  attr :segments, :list, required: true

  defp inline_content(assigns) do
    ~H"""
    <.inline_segment :for={segment <- @segments} segment={segment} />
    """
  end

  attr :segment, :map, required: true

  defp inline_segment(%{segment: %{type: :strong, content: content}} = assigns) do
    assigns = assign(assigns, :content, content)

    ~H"""
    <strong>{@content}</strong>
    """
  end

  defp inline_segment(%{segment: %{type: :text, content: content}} = assigns) do
    assigns = assign(assigns, :content, content)

    ~H"""
    {@content}
    """
  end

  defp inline_segments(text) when is_binary(text) do
    Regex.split(~r/(\*\*[^*]+\*\*|__[^_]+__)/, text, include_captures: true, trim: true)
    |> Enum.map(&inline_segment_from_text/1)
  end

  defp inline_segments(text), do: [%{type: :text, content: to_string(text)}]

  defp inline_segment_from_text("**" <> rest) do
    %{type: :strong, content: String.trim_trailing(rest, "**")}
  end

  defp inline_segment_from_text("__" <> rest) do
    %{type: :strong, content: String.trim_trailing(rest, "__")}
  end

  defp inline_segment_from_text(text), do: %{type: :text, content: text}

  defp strip_inline_bold_markers(text) when is_binary(text) do
    text
    |> String.replace(~r/\*\*(.*?)\*\*/, "\\1")
    |> String.replace(~r/__(.*?)__/, "\\1")
  end

  defp strip_inline_bold_markers(text), do: text

  defp markdown_blocks(body) do
    blocks =
      body
      |> to_string()
      |> String.split("\n")
      |> Enum.reduce([], fn line, blocks ->
        trimmed = String.trim(line)

        cond do
          trimmed == "" ->
            append_markdown_block(blocks, %{type: :spacer})

          String.starts_with?(trimmed, "# ") ->
            append_markdown_block(blocks, %{
              type: :h1,
              content: String.trim_leading(trimmed, "# ")
            })

          String.starts_with?(trimmed, "## ") ->
            append_markdown_block(blocks, %{
              type: :h2,
              content: String.trim_leading(trimmed, "## ")
            })

          String.starts_with?(trimmed, "### ") ->
            append_markdown_block(blocks, %{
              type: :h3,
              content: String.trim_leading(trimmed, "### ")
            })

          bullet_line?(trimmed) ->
            append_markdown_block(blocks, %{
              type: :bullet,
              content: strip_markdown_prefix(trimmed)
            })

          true ->
            append_markdown_block(blocks, %{type: :paragraph, content: trimmed})
        end
      end)
      |> Enum.reverse()

    if Enum.all?(blocks, &(&1.type == :spacer)), do: [], else: blocks
  end

  defp append_markdown_block([], block), do: [block]

  defp append_markdown_block([%{type: :spacer} | _] = blocks, %{type: :spacer}), do: blocks

  defp append_markdown_block([last | rest], %{type: :paragraph, content: content})
       when last.type in [:paragraph, :bullet] do
    [%{last | content: "#{last.content} #{content}"} | rest]
  end

  defp append_markdown_block(blocks, block), do: [block | blocks]

  defp bullet_line?(line) do
    String.starts_with?(line, "- ") or
      String.starts_with?(line, "* ") or
      Regex.match?(~r/^\d+\.\s+/, line)
  end

  defp strip_markdown_prefix(line) do
    line
    |> String.replace(~r/^\#{1,6}\s+/, "")
    |> String.replace(~r/^[-*+]\s+/, "")
    |> String.replace(~r/^\d+\.\s+/, "")
  end
end
