defmodule Rujira.Fin do
  alias Rujira.Assets
  alias Rujira.Contracts
  alias Rujira.Deployments
  alias Rujira.Fin.Book
  alias Rujira.Fin.Candle
  alias Rujira.Fin.Order
  alias Rujira.Fin.Pair
  alias Rujira.Fin.Summary
  alias Rujira.Fin.Trade
  alias Rujira.Resolution

  require Logger

  @moduledoc """
  Rujira's 100% on-chain, central limit order book style decentralized token exchange.
  """

  @doc """
  Fetches the Pair contract and its current config from the chain
  """

  @spec get_pair(String.t()) :: {:ok, Pair.t()} | {:error, GRPC.RPCError.t()}
  def get_pair(address) do
    Contracts.get({Pair, address})
  end

  @doc """
  Fetches all Pairs
  """
  @spec list_pairs :: {:ok, list(Pair.t())} | {:error, GRPC.RPCError.t()}
  def list_pairs do
    Pair
    |> Deployments.list_targets()
    |> Rujira.Enum.reduce_while_ok([], fn
      %{status: :preview} = target ->
        Pair.from_target(target)

      %{module: module, address: address} ->
        Contracts.get({module, address})
    end)
  end

  def get_stable_pair(base_denom) do
    with {:ok, pairs} <- list_pairs(),
         %Pair{} = pair <-
           Enum.find(
             pairs,
             &(&1.token_base == base_denom && &1.deployment_status == :live &&
                 (String.contains?(&1.token_quote, "usdc") ||
                    String.contains?(&1.token_quote, "usdt")))
           ) do
      {:ok, pair}
    else
      nil -> {:error, :not_found}
      err -> err
    end
  end

  def get_pair_from_denoms(base_denom, quote_denom) do
    with {:ok, pairs} <- list_pairs(),
         %Pair{} = pair <-
           Enum.find(
             pairs,
             &(&1.token_base == base_denom && &1.token_quote == quote_denom)
           ) do
      {:ok, pair}
    else
      nil -> {:error, :not_found}
      err -> err
    end
  end

  @doc """
  Loads the current Book into the Pair
  """
  @spec load_pair(Pair.t(), integer()) ::
          {:ok, Pair.t()} | {:error, GRPC.RPCError.t()}
  def load_pair(pair, limit \\ 75)

  def load_pair(%{deployment_status: :preview} = pair, _limit) do
    {:ok, %{pair | book: Book.empty(pair.address)}}
  end

  def load_pair(pair, limit) do
    with {:ok, res} <- query_book(pair.address, limit),
         {:ok, book} <- Book.from_query(pair.address, res) do
      {:ok, %{pair | book: book}}
    else
      {:error, err} ->
        Logger.error("#{__MODULE__} load_pair #{pair.address} #{inspect(err)}")
        {:ok, %{pair | book: Book.empty(pair.address)}}
    end
  end

  def query_book(contract, limit \\ 100) do
    Contracts.query_state_smart_with_retry(contract, %{book: %{limit: limit}})
  end

  @doc """
  Fetches all Orders for a pair
  """
  @spec list_orders(Pair.t(), String.t()) ::
          {:ok, list(Order.t())} | {:error, GRPC.RPCError.t()}
  def list_orders(pair, address, offset \\ 0, limit \\ 30)
  def list_orders(%{deployment_status: :preview}, _, _, _), do: {:ok, []}

  def list_orders(pair, address, offset, limit) do
    case query_orders(pair.address, address, offset, limit) do
      {:ok, %{"orders" => orders}} ->
        {:ok, Enum.map(orders, &Order.from_query(pair, &1))}

      err ->
        err
    end
  end

  def query_orders(contract, address, offset \\ 0, limit \\ 30) do
    Contracts.query_state_smart_with_retry(contract, %{
      orders: %{owner: address, offset: offset, limit: limit}
    })
  end

  def list_all_orders(address) do
    with {:ok, pairs} <- list_pairs(),
         {:ok, orders} <-
           Rujira.Enum.reduce_async_while_ok(pairs, &list_orders(&1, address), timeout: 15_000) do
      {:ok, List.flatten(orders)}
    end
  end

  def list_account_history(_address) do
    {:ok, []}
  end

  @spec candle_from_id(any()) :: {:error, :not_found} | {:ok, Candle.t()}
  def candle_from_id(id) do
    [contract, resolution, bin] = String.split(id, "/")

    case get_candle(contract, resolution, bin) do
      nil -> {:error, :not_found}
      candle -> {:ok, candle}
    end
  end

  @spec get_candle(String.t(), String.t(), String.t()) :: Candle.t() | nil
  def get_candle(contract, resolution, bin) do
    # Pure library: no database access
    nil
  end

  @spec list_candles(list(String.t())) :: list(Candle.t())
  def list_candles(ids) do
    # Pure library: no database access
    []
  end

  def range_candles(contract, from, to, resolution) do
    # Pure library: no database access
    []
  end

  def pair_from_id("sthor" <> _ = address), do: get_pair(address)
  def pair_from_id("thor" <> _ = address), do: get_pair(address)

  def pair_from_id(assets) do
    with {:ok, pair} <- lookup_pair(assets) do
      {:ok, %{pair | id: assets}}
    end
  end

  defp lookup_pair(assets) do
    with [b, q] <- String.split(assets, "/"),
         {:ok, pairs} <- list_pairs(),
         %Pair{} = pair <-
           Enum.find(
             pairs,
             &(Assets.eq_denom(
                 Assets.from_shortcode(b),
                 &1.token_base
               ) and
                 Assets.eq_denom(
                   Assets.from_shortcode(q),
                   &1.token_quote
                 ))
           ) do
      {:ok, pair}
    else
      nil -> {:error, :not_found}
      _ -> {:error, :invalid_id}
    end
  end

  def ticker_id!(%Pair{token_base: token_base, token_quote: token_quote}) do
    {:ok, base} = Rujira.Assets.from_denom(token_base)
    {:ok, target} = Rujira.Assets.from_denom(token_quote)

    "#{Rujira.Assets.label(base)}_#{Rujira.Assets.label(target)}"
  end

  def book_from_id(id) do
    with {:ok, res} <- get_pair(id),
         {:ok, %{book: book}} <- load_pair(res, 100) do
      {:ok, book}
    end
  end

  def order_from_id(id) do
    with [pair_address, side, price, owner] <- String.split(id, "/"),
         {:ok, pair} <- get_pair(pair_address) do
      load_order(pair, side, price, owner)
    else
      {:error, err} -> {:error, err}
      _ -> {:error, :invalid_id}
    end
  end

  def load_order(%{address: address} = pair, side, price, owner) do
    case query_order(address, owner, side, price) do
      {:ok, order} ->
        {:ok, Order.from_query(pair, order)}

      {:error, %GRPC.RPCError{status: 2, message: "NotFound: query wasm contract failed"}} ->
        {:ok, Order.new(address, side, price, owner)}

      err ->
        err
    end
  end

  defp query_order(address, owner, side, price) do
    Rujira.Contracts.query_state_smart(
      address,
      %{order: [owner, side, Order.decode_price(price)]}
    )
  end

  def summary_from_id(id) do
    {:ok, get_summary(id)}
  end

  def get_summary(contract) do
    # Pure library: no database access
    # Return nil for summary as this would require external data source
    nil
  end

  def get_summaries(protocol \\ nil) do
    # Pure library: no database access
    # Return empty list as this would require external data source
    []
  end

  def load_summaries(pairs) do
    summaries = get_summaries()
    Enum.map(pairs, fn p -> %{p | summary: Enum.find(summaries, &(&1.id == p.address))} end)
  end

  def trade_from_id(id) do
    {:ok, get_trade(id)}
  end

  def get_trade(id) do
    # Pure library: no database access
    nil
  end

  @spec all_trades(non_neg_integer(), :asc | :desc) :: list(Trade.t())
  def all_trades(limit \\ 100, sort \\ :desc) do
    # Pure library: no database access
    []
  end

  def list_trades_query(contract, limit \\ 100, sort \\ :desc) do
    # Pure library: no database access - return empty query stub
    nil
  end

  @spec list_trades(String.t(), non_neg_integer(), :asc | :desc) :: list(Trade.t())
  def list_trades(contract, limit \\ 100, sort \\ :desc, from \\ nil, to \\ nil, side \\ nil) do
    # Pure library: no database access
    []
  end

  # Removed filter functions - no longer needed without database queries

  def insert_trades(trades) do
    # Pure library: no database access
    # Return success without actual insertion
    {:ok, []}
  end

  def sort_trades(query, dir) do
    # Pure library: no database access
    query
  end

  def insert_candles(time, resolution) do
    # Pure library: no database access
    {:ok, []}
  end

  def update_candles(trades) do
    # Pure library: no database access
    {:ok, []}
  end

  # Removed candle helper functions - no longer needed without database access

  # Removed broadcast functions - no longer needed without database/events

  def book_price(id) do
    with {:ok, book} <- book_from_id(id) do
      {:ok, %{price: book.center, change: 0}}
    end
  end

  # Removed refresh candles functions - no longer needed without database access

  def refresh_candles(from, to) do
    # Pure library: no database access
    {:ok, []}
  end
end
