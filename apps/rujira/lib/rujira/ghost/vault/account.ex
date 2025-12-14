defmodule Rujira.Ghost.Vault.Account do
  @moduledoc """
  Defines structure of a user's deposit into a Ghost lending vault
  """
  alias Rujira.Ghost.Vault
  defstruct [:id, :account, :vault, :shares, :value]

  @type t :: %__MODULE__{
          id: String.t(),
          vault: Vault.t(),
          account: String.t(),
          shares: non_neg_integer(),
          value: non_neg_integer()
        }

  def from_balance(
        %Vault{address: address, status: %{deposit_pool: %{ratio: ratio}}} = vault,
        owner,
        balance
      ) do
    %__MODULE__{
      id: "#{address}/#{owner}",
      vault: vault,
      account: owner,
      shares: balance,
      value:
        Decimal.new(balance)
        |> Decimal.mult(ratio)
        |> Decimal.round(0, :floor)
        |> Decimal.to_integer()
    }
  end

  def empty(%Vault{address: address} = vault, owner) do
    %__MODULE__{
      id: "#{address}/#{owner}",
      vault: vault,
      account: owner,
      shares: 0,
      value: 0
    }
  end
end
