defmodule Rujira.Math do
  @moduledoc """
  Math utilities for Rujira financial calculations
  """

  @doc """
  Multiply two numbers and round down to integer
  """
  @spec mul_floor(number(), number()) :: integer()
  def mul_floor(a, b) do
    Decimal.new(a)
    |> Decimal.mult(Decimal.new(b))
    |> Decimal.round(0, :floor)
    |> Decimal.to_integer()
  end

  @doc """
  Divide two numbers and round down to integer
  """
  @spec div_floor(number(), number()) :: integer()
  def div_floor(a, b) do
    Decimal.new(a)
    |> Decimal.div(Decimal.new(b))
    |> Decimal.round(0, :floor)
    |> Decimal.to_integer()
  end

  @doc """
  Safe division that returns 0 if divisor is zero
  """
  @spec safe_div(number(), number()) :: Decimal.t()
  def safe_div(a, b) do
    b_decimal = Decimal.new(b)

    if Decimal.eq?(b_decimal, Decimal.new(0)) do
      Decimal.new(0)
    else
      Decimal.div(Decimal.new(a), b_decimal)
    end
  end

  @doc """
  Convert number from one decimal precision to another
  """
  @spec normalize(number() | float(), integer(), integer()) :: Decimal.t()
  def normalize(a, from \\ 0, to \\ 8)

  def normalize(a, from, to) when is_float(a),
    do: do_normalize(Decimal.from_float(a), from, to)

  def normalize(a, from, to),
    do: do_normalize(Decimal.new(a), from, to)

  defp do_normalize(a, from, to) when to >= from do
    Decimal.mult(a, Decimal.new(10 ** (to - from)))
  end

  defp do_normalize(a, from, to) do
    Decimal.mult(a, Decimal.from_float(10 ** (to - from)))
  end

  @doc """
  Round down to integer using floor
  """
  @spec floor(number()) :: integer()
  def floor(a) do
    Decimal.new(a)
    |> Decimal.round(0, :floor)
    |> Decimal.to_integer()
  end
end
