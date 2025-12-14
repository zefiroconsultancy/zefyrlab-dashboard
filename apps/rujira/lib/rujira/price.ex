defmodule Rujira.Price do
  @moduledoc """
  Fetches price data from multiple sources on chain using Asset structs.

  Price sources priority:
  1. FIN DEX for specific tokens (AUTO, NAMI, LQDY)
  2. Thorchain enshrined oracle prices
  3. TOR (Thorchain) pool prices for layer 1 assets
  """
  alias Rujira.Assets
  alias Rujira.Assets.Asset
  alias Rujira.Fin
  alias Rujira.Math
  alias Rujira.Thorchain

  @doc "Fetches prices for multiple assets concurrently."
  @spec get([Asset.t()]) ::
          {:ok, %{Asset.t() => Decimal.t()}} | {:error, any()}
  def get(assets) when is_list(assets) do
    Rujira.Enum.reduce_async_while_ok(assets, fn asset ->
      case get(asset) do
        {:ok, value} -> {:ok, {asset, value}}
        {:error, reason} -> {:error, reason}
      end
    end)
    |> case do
      {:ok, results} -> {:ok, Map.new(results)}
      error -> error
    end
  end

  def get(%Asset{} = asset), do: fetch(asset)

  def get(_), do: {:error, :invalid_asset}

  @doc "Calculates USD value for asset amount in smallest units."
  @spec value_usd(Asset.t(), integer()) :: integer()
  def value_usd(%Asset{} = asset, amount) do
    case get(asset) do
      {:ok, price} ->
        Math.mul_floor(amount, price)

      _ ->
        0
    end
  end

  @spec value_usd(any(), any(), any()) :: 0
  def value_usd(_, _, _), do: 0

  # -------------------
  # Private functions
  # -------------------

  # Special cases: Use FIN DEX for these specific tokens
  defp fetch(%Asset{symbol: "AUTO"}), do: fin_price("thor.auto")
  defp fetch(%Asset{symbol: "NAMI"}), do: fin_price("thor.nami")
  defp fetch(%Asset{symbol: "LQDY"}), do: fin_price("thor.lqdy")

  # Default price fetching: Try oracle first, fallback to TOR pool price
  defp fetch(%Asset{symbol: symbol} = asset) do
    case Thorchain.oracle_price(symbol) do
      {:ok, price} ->
        {:ok, price}

      _ ->
        # Convert to layer 1 asset and get TOR pool price
        layer1_asset = Assets.to_layer1(asset)
        Thorchain.tor_price(layer1_asset.id)
    end
  end

  # Get price from FIN DEX stable pairs
  defp fin_price(id) do
    with {:ok, pair} <- Fin.get_stable_pair(id),
         {:ok, %{book: book}} <- Fin.load_pair(pair, 1) do
      {:ok, book.center}
    end
  end
end
