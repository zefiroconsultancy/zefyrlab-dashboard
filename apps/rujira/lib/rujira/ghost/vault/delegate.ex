defmodule Rujira.Ghost.Vault.Delegate do
  @moduledoc """
  Ghost vault delegate management.
  """
  alias Rujira.Ghost.Vault.Borrower

  defstruct [
    :borrower,
    :address,
    :current,
    :shares
  ]

  def from_query(%{
        "borrower" => borrower,
        "addr" => address,
        "current" => current,
        "shares" => shares
      }) do
    with {:ok, borrower} <- Borrower.from_query(borrower),
         {current, ""} <- Integer.parse(current),
         {shares, ""} <- Integer.parse(shares) do
      {:ok,
       %__MODULE__{
         borrower: borrower,
         address: address,
         current: current,
         shares: shares
       }}
    end
  end
end
