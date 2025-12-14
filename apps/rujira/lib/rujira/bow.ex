defmodule Rujira.Bow do
  @moduledoc """
  Rujira Bow - AMM pools.
  """
  alias Rujira.Bow.Account
  alias Rujira.Bow.Xyk
  alias Rujira.Chains.Thor
  alias Rujira.Contracts
  alias Rujira.Deployments
  alias Rujira.Fin
  alias Rujira.Fin.Book
  alias Rujira.Fin.Trade
  alias Rujira.Math

  @doc """
  Fetches all Bow Pools
  """

  @spec list_pools ::
          {:ok, list(Xyk.t())} | {:error, GRPC.RPCError.t()}
  def list_pools do
    __MODULE__
    |> Deployments.list_targets()
    |> Rujira.Enum.reduce_async_while_ok(&load_pool/1, timeout: 30_000)
  end

  @doc """
  Fetches the Merge Pool contract and its current config from the chain
  """

  def load_pool(%{status: :preview} = target), do: Xyk.from_target(target)

  def load_pool(%{address: address}) do
    with {:ok, %{"xyk" => xyk}} <- query_pool(address) do
      Xyk.from_query(address, xyk)
    end
  end

  defp query_pool(address) do
    Contracts.query_state_smart(address, %{strategy: %{}})
  end

  def pool_from_id(id) do
    case load_pool(%{address: id}) do
      {:ok, pool} -> {:ok, pool}
      _ -> Contracts.from_target({Xyk, id})
    end
  end

  @doc """
  Loads an Account Pool by account address
  """
  @spec load_account(Xyk.t() | nil, String.t()) ::
          {:ok, Account.t()} | {:error, GRPC.RPCError.t()}
  def load_account(nil, _), do: {:ok, nil}

  def load_account(pool, account) do
    with {:ok, %{amount: shares}} <-
           Thor.balance_of(account, pool.config.share_denom) do
      {:ok,
       %Account{
         id: "#{account}/#{pool.config.share_denom}",
         account: account,
         pool: pool,
         shares: shares,
         value: share_value(shares, pool)
       }}
    end
  end

  def account_from_id(id) do
    with [account, denom] <- String.split(id, "/", parts: 2) do
      with {:ok, pool} <- pool_from_share_denom(denom) do
        load_account(pool, account)
      end
    end
  end

  def share_value(_, %Xyk{state: %{shares: 0}}), do: []
  def share_value(_, %Xyk{state: nil}), do: []

  def share_value(shares, %Xyk{config: config, state: %{x: x, y: y, shares: supply}}) do
    ratio = Decimal.div(Decimal.new(shares), Decimal.new(supply))

    [
      %{
        amount: Math.mul_floor(x, ratio),
        denom: config.x
      },
      %{
        amount: Math.mul_floor(y, ratio),
        denom: config.y
      }
    ]
  end

  def fin_pair(contract) do
    with {:ok, pairs} <- Fin.list_pairs(),
         %Fin.Pair{} = pair <-
           Enum.find(pairs, fn %{market_maker: mm} -> mm == contract end) do
      {:ok, pair}
    else
      _ -> {:error, :not_found}
    end
  end

  def load_quotes(address), do: query_quotes(address)

  defp query_quotes(address) do
    with {:ok, %Xyk{config: config, state: state}} <- load_pool(%{address: address}) do
      {:ok,
       %Book{
         id: address,
         asks: Xyk.do_quotes(config, state, :ask),
         bids: Xyk.do_quotes(config, state, :bid)
       }
       |> Book.populate()}
    end
  end

  def share_denom_map do
    case list_pools() do
      {:ok, pools} ->
        pools
        |> Enum.map(&{&1.config.share_denom, &1})
        |> Enum.into(%{})

      error ->
        error
    end
  end

  def pool_from_share_denom(share_denom) do
    case share_denom_map() do
      %{} = map ->
        case Map.get(map, share_denom) do
          nil -> {:error, :not_found}
          pool -> {:ok, pool}
        end

      error ->
        error
    end
  end

  def init_msg(%{"strategy" => %{"xyk" => xyk}}), do: Xyk.init_msg(xyk)
  def migrate_msg(from, to, %{"strategy" => %{"xyk" => xyk}}), do: Xyk.migrate_msg(from, to, xyk)
  def init_label(id, %{"strategy" => %{"xyk" => xyk}}), do: Xyk.init_label(id, xyk)
end
