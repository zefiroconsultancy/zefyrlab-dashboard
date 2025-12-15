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
    with {:ok, rune_price} <- Price.get(Assets.from_shortcode("RUNE")),
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
          {provider_rewards, bond} =
            provider_info(delta, total_bond, info.bond_providers.providers, providers)

          %{
            revenue_rune: acc.revenue_rune + provider_rewards,
            total_bond: acc.total_bond + bond
          }

        _ ->
          acc
      end
    end)
  end

  defp provider_info(delta, total_bond, providers_info, providers)
       when total_bond > 0 and is_list(providers_info) do
    providers_set = MapSet.new(providers)

    Enum.reduce(providers_info, {0, 0}, fn
      %{bond: provider_bond, bond_address: addr}, {reward_acc, bond_acc}
      when is_integer(provider_bond) and provider_bond > 0 ->
        if MapSet.member?(providers_set, addr) do
          {
            reward_acc + reward_share(delta, provider_bond, total_bond),
            bond_acc + provider_bond
          }
        else
          {reward_acc, bond_acc}
        end

      _other, acc ->
        acc
    end)
  end

  defp provider_info(_delta, _total_bond, _providers_info, _providers), do: {0, 0}

  defp reward_share(delta, provider_bond, total_bond) when total_bond > 0 do
    delta
    |> Decimal.new()
    |> Decimal.mult(Decimal.new(provider_bond))
    |> Decimal.div(Decimal.new(total_bond))
    |> Decimal.round(0, :floor)
    |> Decimal.to_integer()
  end

  defp reward_share(_delta, _provider_bond, _total_bond), do: 0

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
