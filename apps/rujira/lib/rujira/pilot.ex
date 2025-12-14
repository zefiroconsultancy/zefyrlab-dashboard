defmodule Rujira.Pilot do
  @moduledoc """
  Rujira.Pilot
  """
  require Logger

  alias Rujira.Contracts
  alias Rujira.Keiko
  alias Rujira.Pilot.Account
  alias Rujira.Pilot.Bid
  alias Rujira.Pilot.BidAction
  alias Rujira.Pilot.Pool
  alias Rujira.Pilot.Sale

  # --- Public API (alphabetical) ---

  @doc "Load an account struct from sale and account."
  def load_account(sale, account) do
    {:ok, %Account{id: "#{sale}/#{account}", sale: sale, account: account}}
  end

  @doc "Queries for a specific bid by owner and premium."
  def bid(address, owner, premium) do
    with {:ok, order_data} <- query_order(address, owner, premium) do
      {:ok, Bid.from_query(%{address: address}, order_data)}
    end
  end

  @doc "Get a bid from its composite ID."
  def bid_from_id(id) do
    [sale, owner, premium] = String.split(id, "/", parts: 3)

    with {:ok, bid_data} <- query_order(sale, owner, premium) do
      {:ok, Bid.from_query(%{address: sale}, bid_data)}
    end
  end

  @doc "Fetches sale for a pilot contract."
  def sale_from_id(address) do
    with {:ok, idx} <- Keiko.idx_sale(address),
         {:ok, %Keiko.Sale{venture: %{sale: sale}}} <- Keiko.query_sale(idx) do
      {:ok, sale}
    end
  end

  @doc "Queries for paginated bids for a specific owner."
  def bids(address, owner, offset, limit) do
    with {:ok, %{"orders" => orders}} <- query_bids(address, owner, offset, limit) do
      Rujira.Enum.reduce_async_while_ok(orders, fn bid ->
        Bid.from_query(%{address: address}, bid)
      end)
    end
  end

  @doc "Summary of bids for a specific owner."
  def bids_summary(address, owner) do
    with {:ok, bids} <- bids(address, owner, nil, nil) do
      Account.Summary.from_bids(bids)
    end
  end

  @doc "Queries for paginated liquidity pools."
  def pools(%Sale{address: address}, offset, limit) do
    with {:ok, %{"pools" => pools}} <- query_pools(address, offset, limit) do
      Rujira.Enum.reduce_async_while_ok(pools, &Pool.from_query/1)
    end
  end

  def query_bids(address, owner, offset, limit) do
    query_params =
      %{
        owner: owner,
        offset: offset,
        limit: limit
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    Contracts.query_state_smart(address, %{orders: query_params})
  end

  def query_order(address, owner, premium) do
    # Rust query expects a tuple [String, u8]
    Contracts.query_state_smart(address, %{order: [owner, premium]})
  end

  def query_pools(address, offset, limit) do
    query_params =
      [offset: offset, limit: limit]
      |> Enum.reject(&is_nil(elem(&1, 1)))
      |> Map.new()

    Contracts.query_state_smart(address, %{pools: query_params})
  end
end
