defmodule Rujira.Ghost.Credit.Collateral do
  @moduledoc """
  Ghost credit collateral management.
  """
  alias Rujira.Account.Balance

  defstruct [
    :collateral,
    :value_full,
    :value_adjusted
  ]

  def from_query(%{
        "collateral" => collateral,
        "value_full" => value_full,
        "value_adjusted" => value_adjusted
      }) do
    with {:ok, collateral} <- parse_collateral(collateral) do
      {:ok,
       %__MODULE__{
         value_full: Decimal.new(value_full) |> Decimal.round() |> Decimal.to_integer(),
         value_adjusted: Decimal.new(value_adjusted) |> Decimal.round() |> Decimal.to_integer(),
         collateral: collateral
       }}
    end
  end

  def parse_collateral(%{"coin" => coin}), do: Balance.parse(coin)
end
