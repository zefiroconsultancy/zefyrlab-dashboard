defmodule Rujira.Account do
  @moduledoc """
  Account management.
  """

  defstruct [:address, :balances]

  # Aliases
  alias Cosmos.Bank.V1beta1.QueryAllBalancesRequest
  alias Cosmos.Bank.V1beta1.QueryAllBalancesResponse
  alias Cosmos.Bank.V1beta1.QueryBalanceRequest
  alias Cosmos.Bank.V1beta1.QueryBalanceResponse
  alias Rujira.Account.Balance
  alias Rujira.GRPC

  # Imports
  import Cosmos.Bank.V1beta1.Query.Stub

  def from_address(address, channel) do
    %__MODULE__{
      address: address,
      balances: balances(%__MODULE__{address: address}, channel)
    }
  end

  def balance_of(%__MODULE__{address: address}, denom, channel) do
    req = %QueryBalanceRequest{address: address, denom: denom}

    with {:ok, %QueryBalanceResponse{balance: coin}} <-
           GRPC.request(channel, &balance/2, req) do
      Balance.parse(coin)
    end
  end

  def balances(%__MODULE__{address: address}, channel) do
    req = %QueryAllBalancesRequest{address: address}

    with {:ok, %QueryAllBalancesResponse{balances: balances}} <-
           GRPC.request(channel, &all_balances/2, req) do
      Rujira.Enum.reduce_while_ok(balances, &Balance.parse/1)
    end
  end
end
