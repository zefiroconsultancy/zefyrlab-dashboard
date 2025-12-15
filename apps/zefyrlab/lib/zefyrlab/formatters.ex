defmodule Zefyrlab.Formatters do
  @moduledoc """
  Shared formatting utilities for numbers, currency, and RUNE tokens.

  All data transformation and formatting happens in the domain layer.
  The web layer receives pre-formatted strings ready for display.

  ## Constants

  - All amounts are stored with 8 decimal places in the database
  - No distinction between RUNE and USD conversion (both use same decimals)
  """

  alias Decimal, as: D

  # All amounts stored with 8 decimal places
  @decimals 100_000_000

  # ============================================================================
  # Number Formatting
  # ============================================================================

  def format_number(num) when is_integer(num) do
    num
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  def format_number(%D{} = num), do: format_number(D.to_integer(num))
  def format_number(nil), do: "0"
  def format_number(_), do: "0"

  def format_large_number(num) when is_number(num) do
    cond do
      num >= 1_000_000_000 -> "$#{Float.round(num / 1_000_000_000, 2)}B"
      num >= 1_000_000 -> "$#{Float.round(num / 1_000_000, 2)}M"
      num >= 1_000 -> "$#{Float.round(num / 1_000, 2)}K"
      true -> "$#{num}"
    end
  end

  def format_large_number(_), do: "$0"

  def format_percentage(value) when is_number(value) do
    :erlang.float_to_binary(value * 100, decimals: 1) <> "%"
  end

  def format_percentage(_), do: "0.0%"

  def format_float(value, decimals) when is_number(value) and is_integer(decimals) do
    :erlang.float_to_binary(value, decimals: decimals)
  end

  def format_float(_, _), do: "0.0"

  # ============================================================================
  # Currency Formatting
  # ============================================================================

  def format_currency(amount) when is_integer(amount) do
    "$" <> format_number(amount)
  end

  def format_currency(amount) when is_float(amount) do
    "$" <> format_number(trunc(amount))
  end

  def format_currency(_), do: "$0"

  def format_currency_decimal(%D{} = amount) do
    amount
    |> D.to_float()
    |> to_decimal()
    |> trunc()
    |> format_currency()
  end

  def format_currency_decimal(_), do: "$0"

  # ============================================================================
  # RUNE Token Formatting (8 decimal places)
  # ============================================================================

  def format_rune(base_units) when is_integer(base_units) do
    decimal = base_units / @decimals

    # Format with 2 decimal places
    formatted = :erlang.float_to_binary(decimal, decimals: 2)

    # Add thousands separators
    [integer_part, decimal_part] = String.split(formatted, ".")

    integer_with_commas =
      integer_part
      |> String.graphemes()
      |> Enum.reverse()
      |> Enum.chunk_every(3)
      |> Enum.join(",")
      |> String.reverse()

    integer_with_commas <> "." <> decimal_part
  end

  def format_rune(_), do: "0.00"

  # ============================================================================
  # Decimal Conversion Helpers
  # ============================================================================

  def to_decimal(base_units) when is_integer(base_units) do
    base_units / @decimals
  end

  def to_decimal(%D{} = base_units) do
    D.to_float(base_units) / @decimals
  end

  def to_decimal(base_units) when is_float(base_units) do
    base_units / @decimals
  end

  def to_decimal(nil), do: 0.0
  def to_decimal(_), do: 0.0

  def d_to_float(%D{} = val), do: D.to_float(val)
  def d_to_float(nil), do: 0
  def d_to_float(val) when is_number(val), do: val * 1.0
  def d_to_float(_), do: 0.0
end
