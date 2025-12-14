defmodule Rujira.Ghost.Vault.Borrower do
  @moduledoc """
  Ghost vault borrower management.
  """

  defstruct [
    :address,
    :denom,
    :current,
    :limit,
    :shares,
    :available
  ]

  def from_query(%{
        "addr" => addr,
        "denom" => denom,
        "current" => current,
        "limit" => limit,
        "shares" => shares,
        "available" => available
      }) do
    with {current, ""} <- Integer.parse(current),
         {limit, ""} <- Integer.parse(limit),
         {shares, ""} <- Integer.parse(shares),
         {available, ""} <- Integer.parse(available) do
      {:ok,
       %__MODULE__{
         address: addr,
         denom: denom,
         current: current,
         limit: limit,
         shares: shares,
         available: available
       }}
    end
  end
end
