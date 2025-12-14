defmodule Rujira.Ghost.Credit.Account do
  @moduledoc """
  Ghost credit account management.
  """
  alias Rujira.Ghost.Credit.Collateral
  alias Rujira.Ghost.Credit.Debt

  defstruct [:id, :owner, :account, :idx, :collaterals, :debts, :ltv, :value_usd]

  def from_query(%{
        "owner" => owner,
        "idx" => idx,
        "account" => account,
        "collaterals" => collaterals,
        "debts" => debts,
        "ltv" => ltv
      }) do
    with {ltv, ""} <- Decimal.parse(ltv),
         {:ok, account} <- parse_account(account),
         {:ok, collaterals} <-
           Rujira.Enum.reduce_while_ok(collaterals, [], &Collateral.from_query/1),
         {:ok, debts} <- Rujira.Enum.reduce_while_ok(debts, [], &Debt.from_query/1),
         {idx, ""} <- Integer.parse(idx) do
      value_usd =
        Enum.reduce(collaterals, 0, &(&1.value_full + &2)) -
          Enum.reduce(debts, 0, &(&1.value + &2))

      {:ok,
       %__MODULE__{
         id: account.address,
         owner: owner,
         account: account,
         idx: idx,
         collaterals: collaterals,
         debts: debts,
         ltv: ltv,
         value_usd: value_usd
       }}
    end
  end

  def parse_account(%{
        "addr" => addr,
        "admin" => admin
      }) do
    {:ok,
     %{
       address: addr,
       admin: admin
     }}
  end

  @doc """
  Checks if an account has any debt.
  Returns true if the account has at least one debt with value > 0.
  Used to filter accounts for liquidation bot (only accounts with debt can be liquidated).
  """
  def has_debt?(%__MODULE__{debts: debts}) when is_list(debts) do
    debts != [] and Enum.any?(debts, fn d -> d.value > 0 end)
  end

  def has_debt?(_), do: false
end
