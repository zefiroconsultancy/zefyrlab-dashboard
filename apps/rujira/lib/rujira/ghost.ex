defmodule Rujira.Ghost do
  @moduledoc """
  Rujira Ghost - Interfaces for the Ghost borrow, lend & credit protocol
  """
  alias Rujira.Chains.Thor
  alias Rujira.Contracts
  alias Rujira.Deployments
  alias Rujira.Ghost.Credit
  alias Rujira.Ghost.Vault

  use Memoize

  def vault_from_id(id) do
    case Deployments.list_targets(Vault)
         |> Enum.find(&(&1.address == id)) do
      nil -> {:error, :not_found}
      target -> Vault.from_target(target)
    end
  end

  def list_vaults do
    Vault
    |> Deployments.list_targets()
    |> Rujira.Enum.reduce_async_while_ok(&Vault.from_target/1)
  end

  def load_vault(%Vault{deployment_status: :preview} = vault) do
    {:ok, %{vault | status: %Vault.Status{}}}
  end

  def load_vault(%Vault{address: address} = vault) do
    with {:ok, status} <- query_vault_status(address),
         {:ok, status} <- Vault.Status.from_query(status) do
      {:ok, %{vault | status: status}}
    end
  end

  defp query_vault_status(address) do
    Contracts.query_state_smart(address, %{status: %{}})
  end

  def query_vault_borrower(vault, address) do
    Contracts.query_state_smart(vault, %{borrower: %{addr: address}})
  end

  def vault_account_from_id(id) do
    with [contract, owner] <- String.split(id, "/"),
         {:ok, vault} <- vault_from_id(contract) do
      load_vault_account(vault, owner)
    else
      _ ->
        {:error, :invalid_id}
    end
  end

  @spec load_vault_account(Vault.t() | nil, String.t()) ::
          {:ok, Vault.Account.t()} | {:error, GRPC.RPCError.t()}
  def load_vault_account(nil, _), do: {:ok, nil}

  def load_vault_account(vault, account) do
    with {:ok, %{amount: amount}} <- Thor.balance_of(account, vault.receipt_denom),
         {:ok, vault} <- load_vault(vault) do
      {:ok, Vault.Account.from_balance(vault, account, amount)}
    else
      _ ->
        {:ok, Vault.Account.empty(vault, account)}
    end
  end

  # ----------- Rujira - Ghost Credit -------------
  def credit do
    with {:ok, address} <- credit_address() do
      Contracts.get({Credit, address})
    end
  end

  def credit_address do
    case Deployments.get_target(Credit, "ghost-credit") do
      nil -> {:error, :not_found}
      target -> {:ok, target.address}
    end
  end

  def all_credit_accounts do
    with {:ok, accounts} <- query_all_credit_accounts() do
      Rujira.Enum.reduce_async_while_ok(accounts, &Credit.Account.from_query/1)
    end
  end

  def credit_debt_vault(%Vault.Delegate{borrower: borrower}) do
    credit_debt_vault(borrower)
  end

  def credit_debt_vault(%Vault.Borrower{denom: denom}) do
    with {:ok, vaults} <- list_vaults(),
         %Vault{} = vault <- Enum.find(vaults, &(&1.denom == denom)) do
      {:ok, vault}
    else
      _ -> {:error, :not_found}
    end
  end

  def credit_from_id(id) do
    Contracts.get({Credit, id})
  end

  def credit_account_from_id(id) do
    with {:ok, account} <- query_credit_account(id) do
      Credit.Account.from_query(account)
    end
  end

  def load_credit_borrows do
    with {:ok, credit_address} <- credit_address(),
         {:ok, vaults} <- list_vaults() do
      Rujira.Enum.reduce_async_while_ok(
        vaults,
        fn %{address: address} ->
          case query_vault_borrower(address, credit_address) do
            {:ok, res} -> Vault.Borrower.from_query(res)
            _ -> :skip
          end
        end
      )
    end
  end

  def load_credit_accounts(owner) do
    with {:ok, %{"accounts" => accounts}} <- query_credit_accounts(owner) do
      Rujira.Enum.reduce_async_while_ok(accounts, &Credit.Account.from_query/1)
    end
  end

  def next_credit_account(owner), do: query_next_credit_account(owner)

  def query_credit_account(id) do
    with {:ok, address} <- credit_address() do
      Contracts.query_state_smart(address, %{account: id})
    end
  end

  defmemo query_all_credit_accounts() do
    with {:ok, address} <- credit_address() do
      do_query_all_credit_accounts(address)
    end
  end

  def do_query_all_credit_accounts(address, cursor \\ nil, acc \\ []) do
    with {:ok, %{"accounts" => accounts}} <-
           Contracts.query_state_smart(address, %{all_accounts: %{cursor: cursor}}) do
      if Enum.count(accounts) < 100 do
        {:ok, acc ++ accounts}
      else
        last = Enum.at(accounts, -1)
        do_query_all_credit_accounts(address, last.account.addr, acc ++ accounts)
      end
    end
  end

  def query_credit_accounts(owner) do
    with {:ok, address} <- credit_address() do
      Contracts.query_state_smart(address, %{accounts: owner})
    end
  end

  def query_credit_borrowers() do
    with {:ok, address} <- credit_address() do
      Contracts.query_state_smart(address, %{borrows: %{}})
    end
  end

  def query_next_credit_account(owner) do
    with {:ok, address} <- credit_address(),
         {:ok, [account, idx]} <- Contracts.query_state_smart(address, %{next: owner}),
         {idx, ""} <- Integer.parse(idx) do
      {:ok, %{account: account, idx: idx}}
    end
  end
end
