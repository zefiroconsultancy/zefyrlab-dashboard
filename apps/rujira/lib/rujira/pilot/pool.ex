defmodule Rujira.Pilot.Pool do
  @moduledoc """
  This module parses the pool data from the Pilot contract into a the correct Rujira Pilot struct
  """
  defstruct [
    :slot,
    :premium,
    :rate,
    :epoch,
    :total,
    :eligible,
    :eligible_quote,
    :non_eligible,
    :non_eligible_quote
  ]

  @type t :: %__MODULE__{
          slot: non_neg_integer(),
          premium: non_neg_integer(),
          rate: Decimal.t(),
          epoch: non_neg_integer(),
          total: non_neg_integer(),
          eligible: non_neg_integer(),
          eligible_quote: non_neg_integer(),
          non_eligible: non_neg_integer(),
          non_eligible_quote: non_neg_integer()
        }

  def from_query(%{
        "price" => price,
        # it's already an integer
        "premium" => premium,
        # it's already an integer
        "epoch" => epoch,
        "total" => total
      }) do
    with {total, ""} <- Integer.parse(total),
         {price, ""} <- Decimal.parse(price) do
      {:ok,
       %__MODULE__{
         slot: premium,
         premium: premium,
         rate: price,
         epoch: epoch,
         total: total,
         eligible: 0,
         eligible_quote: 0,
         non_eligible: 0,
         non_eligible_quote: 0
       }}
    end
  end

  def calculate_eligible(pools, sale_amount) do
    {pools, _allocated_tokens} =
      pools
      |> Enum.sort_by(& &1.premium, :asc)
      |> Enum.map_reduce(Decimal.new(0), fn pool, allocated_tokens ->
        do_eligible(pool, sale_amount, allocated_tokens)
      end)

    {:ok, pools}
  end

  defp do_eligible(pool, sale_amount, allocated_tokens) do
    sale_amount = Decimal.new(sale_amount)
    # calculate how many tokens are sold in this pool
    token_sold = Decimal.div(pool.total, pool.rate)

    # compare the current allocated tokens to the sale amount
    case Decimal.compare(allocated_tokens, sale_amount) do
      # if the current allocated tokens are less than the sale amount, then the pool is eligible
      :lt ->
        # calculate the remaining tokens available for sale
        remaining_tokens = Decimal.sub(sale_amount, allocated_tokens)

        # compare the remaining tokens to the token sold
        case Decimal.compare(remaining_tokens, token_sold) do
          :lt ->
            # if the remaining tokens are less than the token sold, then the pool is partially filled
            # calculate the eligible quota that should be allocated to this pool
            eligible_quota = Decimal.mult(remaining_tokens, pool.rate)
            # calculate the non-eligible quota that should be allocated to this pool
            non_eligible = Decimal.sub(token_sold, remaining_tokens)
            # calculate the non-eligible quota that should be allocated to this pool
            non_eligible_quota = Decimal.mult(non_eligible, pool.rate)

            {
              add_eligible(
                pool,
                remaining_tokens,
                non_eligible,
                eligible_quota,
                non_eligible_quota
              ),
              sale_amount
            }

          # if the remaining tokens are greater than or equal to the token sold, then the pool can be fully filled
          _ ->
            # add the token sold to the allocated tokens
            new_allocated_tokens = Decimal.add(allocated_tokens, token_sold)

            # eligible is all the token sold, eligible_quote is the total value of the pool
            pool = add_eligible(pool, token_sold, 0, pool.total, 0)
            {pool, new_allocated_tokens}
        end

      _ ->
        {add_eligible(pool, 0, token_sold, 0, pool.total), sale_amount}
    end
  end

  defp add_eligible(pool, eligible, non_eligible, eligible_quote, non_eligible_quote) do
    eligible = Decimal.round(eligible) |> Decimal.to_integer()
    non_eligible = Decimal.round(non_eligible) |> Decimal.to_integer()
    eligible_quote = Decimal.round(eligible_quote) |> Decimal.to_integer()
    non_eligible_quote = Decimal.round(non_eligible_quote) |> Decimal.to_integer()

    %__MODULE__{
      slot: pool.slot,
      premium: pool.premium,
      rate: pool.rate,
      epoch: pool.epoch,
      total: pool.total,
      eligible: eligible,
      eligible_quote: eligible_quote,
      non_eligible: non_eligible,
      non_eligible_quote: non_eligible_quote
    }
  end
end
