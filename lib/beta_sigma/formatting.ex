defmodule BetaSigma.Formatting do
  @moduledoc false

  alias Decimal, as: D

  def money(value, currency \\ "KES") do
    currency = currency || "KES"

    value
    |> decimal_or_zero()
    |> D.round(2)
    |> D.to_string(:normal)
    |> delimit_number()
    |> then(&"#{currency} #{&1}")
  end

  defp delimit_number(""), do: "0.00"

  defp delimit_number(value) when is_binary(value) do
    {sign, unsigned} = split_sign(value)
    {whole, fractional} = split_fraction(unsigned)

    sign <> add_thousands_delimiter(whole) <> fractional_suffix(fractional)
  end

  defp split_sign("-" <> rest), do: {"-", rest}
  defp split_sign(value), do: {"", value}

  defp split_fraction(value) do
    case String.split(value, ".", parts: 2) do
      [whole, fractional] -> {whole, fractional}
      [whole] -> {whole, nil}
    end
  end

  defp add_thousands_delimiter(value) do
    value
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.map_join(",", &Enum.join/1)
    |> String.reverse()
  end

  defp fractional_suffix(nil), do: ""
  defp fractional_suffix(""), do: ""
  defp fractional_suffix(fractional), do: "." <> fractional

  defp decimal_or_zero(nil), do: D.new(0)
  defp decimal_or_zero(%D{} = value), do: value
  defp decimal_or_zero(value), do: D.new(value)
end
