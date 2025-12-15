defmodule Zefyrlab.NetworkMetrics.Indexer do
  @moduledoc """
  Swap volume and TVL indexer
  """

  use Zefyrlab.Observer
  require Logger

  alias Rujira.Assets
  alias Rujira.Math
  alias Rujira.Price
  alias Rujira.Thorchain
  alias Zefyrlab.NetworkMetrics

  @impl true
  def handle_new_block(%{header: %{time: time}, end_block_events: events}, state) do
    with {:ok, pools} <- Thorchain.pools() do
      volume =
        events
        |> Enum.map(&scan_event/1)
        |> Enum.sum()

      tvl =
        Enum.reduce(pools, 0, fn pool, acc ->
          acc + Math.mul_floor(Map.get(pool, :balance_rune), 2)
        end)

      Logger.debug("#{__MODULE__} volume: #{volume} and tvl: #{tvl}")

      NetworkMetrics.update_bins(
        %{
          volume: volume,
          tvl: Price.value_usd(Assets.from_shortcode("RUNE"), tvl)
        },
        time
      )
    end

    {:noreply, state}
  end

  def handle_new_block(_message, state), do: {:noreply, state}

  defp scan_event(%{attributes: %{"coin" => coin, "emit_asset" => emit_asset}, type: "swap"}) do
    with {:ok, coin} <- Assets.parse_asset(coin),
         {:ok, emit_asset} <- Assets.parse_asset(emit_asset) do
      Price.value_usd(Assets.from_shortcode("RUNE"), swap_size_rune(coin, emit_asset))
    end
  end

  defp scan_event(_), do: 0

  defp swap_size_rune(coin, emit_asset) do
    case {coin, emit_asset} do
      {{"THOR.RUNE", amount}, _} -> amount
      {_, {"THOR.RUNE", amount}} -> amount
      _ -> 0
    end
  end
end
