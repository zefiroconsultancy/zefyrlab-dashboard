defmodule Zefyrlab.Oracle.Listener do
  @moduledoc """
  Oracle price listener - maintains complete price state and reports all prices to NIF.
  """

  use Zefyrlab.Observer
  require Logger

  defmodule State do
    @moduledoc false
    defstruct [:prices]

    @type t :: %__MODULE__{
            prices: %{String.t() => String.t()}
          }
  end

  @impl true
  def handle_new_block(%{txs: txs, header: %{height: height}}, state) do
    # Extract new prices from this block's events
    new_prices = %{}

    # Merge new prices into state (updates existing, keeps old ones)
    updated_prices = Map.merge(state.prices, new_prices)

    # ALWAYS report complete price map
    Listener.report(:prices, height, updated_prices)

    Logger.debug(
      "Block #{height}: Reported #{map_size(updated_prices)} total prices (#{map_size(new_prices)} updated)"
    )

    {:noreply, %{state | prices: updated_prices}}
  end

  def handle_new_block(_message, state), do: {:noreply, state}

  defp extract_events(%{result: %{events: events}}) when is_list(events), do: events
  defp extract_events(_), do: []

  defp scan_event(%{type: "oracle_price", attributes: %{"symbol" => symbol, "price" => price}}) do
    with {parsed_price, ""} <- Decimal.parse(price) do
      {:ok, symbol, parsed_price}
    end
  end

  defp scan_event(_), do: nil
end
