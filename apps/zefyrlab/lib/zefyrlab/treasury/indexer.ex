defmodule Zefyrlab.Treasury.Indexer do
  @moduledoc """
  Swap volume and TVL indexer
  """

  use Zefyrlab.Observer
  require Logger

  alias Decimal
  alias Rujira.Assets
  alias Rujira.Price
  alias Rujira.Thorchain
  alias Zefyrlab.Treasury.NodeCursor
  alias Zefyrlab.Treasury

  @impl true
  def handle_new_block(
        %{header: %{time: time}, end_block_events: events},
        %{validators: validators, providers: providers} = state
      ) do
    with {:ok, rune_price} <- rune_price(),
         {:ok, nodes_info} <- fetch_nodes(validators) do
      transfers = scan_events(events, providers)
      totals = scan_nodes_info(nodes_info, providers)

      Treasury.update_bins(
        %{
          rune_usd_price: rune_price,
          bonded_rune: totals.total_bond,
          wallet_rune: 0,
          total_rune: totals.total_bond,
          revenue_inflows_rune: totals.revenue_rune,
          capital_inflows_rune: transfers.inflows,
          cost_outflows_rune: transfers.outflows
        },
        time
      )
    end

    {:noreply, state}
  end

  def handle_new_block(_message, state), do: {:noreply, state}

  defp fetch_nodes(validators) do
    Rujira.Enum.reduce_async_while_ok(validators, fn address ->
      case Thorchain.node_info(address) do
        {:ok, info} -> {:ok, {address, info}}
        other -> other
      end
    end)
  end

  defp scan_nodes_info(nodes_info, providers) do
    Enum.reduce(nodes_info, %{revenue_rune: 0, total_bond: 0}, fn {address, info}, acc ->
      total_bond = info.total_bond || 0

      case NodeCursor.delta_and_update(address, info.current_award) do
        {:ok, delta} ->
          provider_rewards = provider_rewards(delta, total_bond, info.bond_providers, providers)

          %{
            revenue_rune: acc.revenue_rune + provider_rewards,
            total_bond: acc.total_bond + total_bond
          }

        _ ->
          acc
      end
    end)
  end

  defp provider_rewards(0, _total_bond, _providers_info, _providers), do: 0

  defp provider_rewards(delta, total_bond, providers_info, providers) when total_bond > 0 do
    providers_list = providers_info && providers_info.providers || []
    providers = providers || []

    providers_for_share =
      if providers == [] do
        providers_list
      else
        Enum.filter(providers_list, &(&1.bond_address in providers))
      end

    providers_for_share
    |> Enum.reduce(0, fn %{bond: bond}, acc ->
      acc + reward_share(delta, bond, total_bond)
    end)
  end

  defp provider_rewards(_delta, _total_bond, _providers_info, _providers), do: 0

  defp reward_share(delta, provider_bond, total_bond) when total_bond > 0 do
    delta
    |> Decimal.new()
    |> Decimal.mult(Decimal.new(provider_bond || 0))
    |> Decimal.div(Decimal.new(total_bond))
    |> Decimal.round(0, :floor)
    |> Decimal.to_integer()
  end

  defp reward_share(_delta, _provider_bond, _total_bond), do: 0

  defp rune_price do
    case Price.get(Assets.from_shortcode("RUNE")) do
      {:ok, price} -> {:ok, price}
      other -> other
    end
  end

  defp scan_events(events, providers) do
    providers = providers || []

    Enum.reduce(events, %{inflows: 0, outflows: 0}, fn
      %{
        type: "transfer",
        attributes: %{"recipient" => recipient, "sender" => sender, "amount" => amount}
      },
      acc ->
        rune_amount = rune_amount(amount)

        cond do
          is_nil(rune_amount) ->
            acc

          sender in providers ->
            %{acc | outflows: acc.outflows + rune_amount}

          recipient in providers ->
            %{acc | inflows: acc.inflows + rune_amount}

          true ->
            acc
        end

      _, acc ->
        acc
    end)
  end

  defp rune_amount(amount_str) do
    with {:ok, coins} <- Assets.parse_coins(amount_str) do
      coins
      |> Enum.find_value(fn {denom, amt} ->
        case String.downcase(denom) do
          "rune" -> amt
          "thor.rune" -> amt
          _ -> nil
        end
      end)
    end
  end
end
