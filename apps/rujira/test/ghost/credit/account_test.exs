defmodule Rujira.Ghost.Credit.AccountTest do
  use ExUnit.Case, async: true

  alias Rujira.Ghost.Credit.Account
  alias Rujira.Ghost.Credit.Debt

  describe "has_debt?/1" do
    test "returns true for account with debt > 0" do
      account = %Account{
        id: "test",
        owner: "owner",
        account: %{address: "addr", admin: "admin"},
        idx: 0,
        collaterals: [],
        debts: [
          %Debt{
            debt: %{
              borrower: %{
                address: "vault1",
                denom: "btc-btc",
                current: 1000,
                limit: 5000,
                shares: 100,
                available: 4000
              }
            },
            value: 50000
          }
        ],
        ltv: Decimal.new("0.5"),
        value_usd: 100_000
      }

      assert Account.has_debt?(account)
    end

    test "returns false for account with empty debts list" do
      account = %Account{
        id: "test",
        owner: "owner",
        account: %{address: "addr", admin: "admin"},
        idx: 0,
        collaterals: [],
        debts: [],
        ltv: Decimal.new("0"),
        value_usd: 100_000
      }

      refute Account.has_debt?(account)
    end

    test "returns false for account with debt value = 0" do
      account = %Account{
        id: "test",
        owner: "owner",
        account: %{address: "addr", admin: "admin"},
        idx: 0,
        collaterals: [],
        debts: [
          %Debt{
            debt: %{
              borrower: %{
                address: "vault1",
                denom: "btc-btc",
                current: 0,
                limit: 5000,
                shares: 0,
                available: 5000
              }
            },
            value: 0
          }
        ],
        ltv: Decimal.new("0"),
        value_usd: 100_000
      }

      refute Account.has_debt?(account)
    end

    test "returns true for account with multiple debts, at least one > 0" do
      account = %Account{
        id: "test",
        owner: "owner",
        account: %{address: "addr", admin: "admin"},
        idx: 0,
        collaterals: [],
        debts: [
          %Debt{
            debt: %{
              borrower: %{
                address: "vault1",
                denom: "btc-btc",
                current: 0,
                limit: 5000,
                shares: 0,
                available: 5000
              }
            },
            value: 0
          },
          %Debt{
            debt: %{
              borrower: %{
                address: "vault2",
                denom: "eth-eth",
                current: 1000,
                limit: 5000,
                shares: 100,
                available: 4000
              }
            },
            value: 50000
          }
        ],
        ltv: Decimal.new("0.3"),
        value_usd: 150_000
      }

      assert Account.has_debt?(account)
    end

    test "returns false for non-Account struct" do
      refute Account.has_debt?(nil)
      refute Account.has_debt?(%{})
      refute Account.has_debt?("not an account")
    end
  end
end
