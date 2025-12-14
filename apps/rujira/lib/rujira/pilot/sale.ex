defmodule Rujira.Pilot.Sale do
  @moduledoc """
  This module Parses the sale data from the Keiko contract into a the correct Rujira Pilot struct
  """

  alias Rujira.Math

  defmodule Stats do
    @moduledoc false

    defstruct [
      :completion_percentage,
      :avg_price,
      :total_bids_value,
      :raise_amount
    ]

    @type t :: %__MODULE__{
            completion_percentage: Decimal.t(),
            avg_price: Decimal.t(),
            total_bids_value: non_neg_integer(),
            raise_amount: non_neg_integer()
          }
  end

  alias Rujira.Pilot
  alias Rujira.Pilot.Pool

  defstruct [
    :id,
    :address,
    :bid_denom,
    :bid_pools,
    :bid_threshold,
    :closes,
    :sale_amount,
    :deposit,
    :fee_amount,
    :max_premium,
    :opens,
    :price,
    :waiting_period,
    :duration,
    :stats
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          address: String.t(),
          bid_denom: String.t(),
          bid_pools: list(Pool.t()),
          bid_threshold: non_neg_integer(),
          closes: DateTime.t(),
          sale_amount: non_neg_integer(),
          deposit: map(),
          fee_amount: non_neg_integer(),
          max_premium: non_neg_integer(),
          opens: DateTime.t(),
          price: Decimal.t(),
          waiting_period: non_neg_integer(),
          duration: non_neg_integer(),
          stats: Stats.t()
        }

  def from_query(
        status,
        sale_amount,
        %{
          "bid_pools_snapshot" => bid_pools_snapshot,
          "contract_address" => contract_address,
          "deposit" => deposit,
          "fee_amount" => fee_amount,
          "pilot" => %{
            "bid_denom" => bid_denom,
            "bid_threshold" => bid_threshold,
            "closes" => closes,
            "max_premium" => max_premium,
            "opens" => opens,
            "price" => price,
            "waiting_period" => waiting_period
          }
        }
      ) do
    with {:ok, deposit} <- parse_deposit(deposit),
         {:ok, bid_threshold} <- parse_optional_integer(bid_threshold),
         {:ok, fee_amount} <- parse_optional_integer(fee_amount),
         {price, ""} <- Decimal.parse(price),
         {opens, ""} <- Integer.parse(opens),
         {:ok, opens} <- DateTime.from_unix(opens, :nanosecond),
         {closes, ""} <- Integer.parse(closes),
         {:ok, closes} <- DateTime.from_unix(closes, :nanosecond) do
      duration = DateTime.diff(closes, opens)

      {:ok,
       %__MODULE__{
         address: contract_address,
         bid_denom: bid_denom,
         bid_threshold: bid_threshold,
         closes: closes,
         sale_amount: sale_amount,
         deposit: deposit,
         fee_amount: fee_amount,
         max_premium: max_premium,
         opens: opens,
         price: price,
         waiting_period: waiting_period,
         duration: duration
       }
       |> parse_bid_pools(bid_pools_snapshot, sale_amount, status)}
    end
  end

  defp parse_bid_pools(sale, %{"pools" => pools}, sale_amount, :executed) do
    with {:ok, pools} <- Rujira.Enum.reduce_while_ok(pools, &Pilot.Pool.from_query/1),
         {:ok, pools} <- Pool.calculate_eligible(pools, sale_amount) do
      %{sale | bid_pools: pools}
    end
  end

  defp parse_bid_pools(sale, _, _, _) do
    case Pilot.pools(sale, nil, nil) do
      {:ok, bid_pools} ->
        with {:ok, pools} <- Pool.calculate_eligible(bid_pools, sale.sale_amount) do
          %{sale | bid_pools: pools}
        end

      # <-- keep everything as-is
      _error ->
        sale
    end
  end

  defp parse_deposit(%{"amount" => amount, "denom" => denom}) do
    with {amount, ""} <- Integer.parse(amount) do
      {:ok, %{amount: amount, denom: denom}}
    end
  end

  defp parse_deposit(nil), do: {:ok, nil}

  defp parse_optional_integer(nil), do: {:ok, nil}

  defp parse_optional_integer(val) do
    with {int, ""} <- Integer.parse(val), do: {:ok, int}
  end

  def calculate_stats(nil, nil) do
    {:ok,
     %Stats{
       completion_percentage: Decimal.new(0),
       avg_price: Decimal.new(0),
       total_bids_value: 0,
       raise_amount: 0
     }}
  end

  def calculate_stats(pools, sale_amount) do
    zero = Decimal.new(0)

    {total_bids_value, allocated_tokens, eligible_tokens, raise_amount} =
      Enum.reduce(pools, {zero, zero, zero, zero}, fn pool, {t, a, e, r} ->
        pool_eligible = Decimal.new(pool.eligible)
        pool_tokens = Decimal.add(pool_eligible, Decimal.new(pool.non_eligible))

        {Decimal.add(t, Decimal.new(pool.total)), Decimal.add(a, pool_tokens),
         Decimal.add(e, pool_eligible), Decimal.add(r, Decimal.new(pool.eligible_quote))}
      end)

    completion_percentage = Decimal.div(allocated_tokens, sale_amount)

    avg_price =
      if Decimal.equal?(raise_amount, zero),
        do: zero,
        else: Decimal.div(raise_amount, eligible_tokens)

    {:ok,
     %Stats{
       completion_percentage: completion_percentage,
       avg_price: avg_price,
       total_bids_value: Math.floor(total_bids_value),
       raise_amount: Math.floor(raise_amount)
     }}
  end
end
