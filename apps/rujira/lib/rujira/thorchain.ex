defmodule Rujira.Thorchain do
  @moduledoc """
  Main module for interacting with the Thorchain blockchain.

  This module provides functionality for querying and interacting with various aspects
  of the Thorchain network, including vaults, nodes, and liquidity providers.
  """

  alias Cosmos.Bank.V1beta1.QueryDenomOwnersRequest
  alias Cosmos.Base.Query.V1beta1.PageRequest
  alias Rujira.Assets
  alias Rujira.Assets.Asset
  alias Rujira.Price
  alias Thorchain.Common.Coin
  alias Thorchain.Common.Tx
  alias Thorchain.Types.BlockEvent
  alias Thorchain.Types.BlockResponseHeader
  alias Thorchain.Types.BlockTxResult
  alias Thorchain.Types.Query.Stub, as: Q
  alias Thorchain.Types.QueryBlockRequest
  alias Thorchain.Types.QueryBlockResponse
  alias Thorchain.Types.QueryBlockTx
  alias Thorchain.Types.QueryInboundAddressesRequest
  alias Thorchain.Types.QueryInboundAddressesResponse
  alias Thorchain.Types.QueryLiquidityProviderRequest
  alias Thorchain.Types.QueryMimirValuesRequest
  alias Thorchain.Types.QueryMimirValuesResponse
  alias Thorchain.Types.QueryNetworkRequest
  alias Thorchain.Types.QueryNodeRequest
  alias Thorchain.Types.QueryNodeResponse
  alias Thorchain.Types.QueryOraclePriceRequest
  alias Thorchain.Types.QueryOutboundFeesRequest
  alias Thorchain.Types.QueryOutboundFeesResponse
  alias Thorchain.Types.QueryPoolsRequest
  alias Thorchain.Types.QueryPoolsResponse
  alias Thorchain.Types.QueryTxRequest
  alias Thorchain.Types.QueryTxResponse

  import Cosmos.Bank.V1beta1.Query.Stub

  def pools(height \\ nil) do
    req = %QueryPoolsRequest{
      height:
        if height do
          Integer.to_string(height)
        else
          ""
        end
    }

    with {:ok, %QueryPoolsResponse{pools: pools}} <-
           Rujira.Node.query(&Q.pools/2, req) do
      {:ok, Enum.map(pools, &cast_pool/1)}
    end
  end

  def pool(asset) do
    # Save hitting the grpc when we already have all the pools for this block
    with {:ok, pools} <- pools(),
         pool when not is_nil(pool) <- Enum.find(pools, &(&1.id == asset)) do
      {:ok, pool}
    else
      nil -> {:ok, nil}
      other -> other
    end
  end

  def inbound_addresses() do
    with {:ok, %QueryInboundAddressesResponse{inbound_addresses: inbound_addresses}} <-
           Rujira.Node.query(&Q.inbound_addresses/3, %QueryInboundAddressesRequest{}, []) do
      {:ok, Enum.map(inbound_addresses, &cast_inbound_address/1)}
    end
  end

  def outbound_fees() do
    with {:ok, %QueryOutboundFeesResponse{outbound_fees: outbound_fees}} <-
           Rujira.Node.query(&Q.outbound_fees/3, %QueryOutboundFeesRequest{}, []) do
      {:ok, Enum.map(outbound_fees, &cast_outbound_fee/1)}
    end
  end

  def liquidity_provider(asset, address) do
    req = %QueryLiquidityProviderRequest{asset: asset, address: address}

    with {:ok, res} <-
           Rujira.Node.query(&Q.liquidity_provider/3, req, []) do
      {:ok, cast_liquidity_provider(res)}
    end
  end

  def cast_liquidity_provider(provider) do
    asset = Assets.from_string(provider.asset)
    rune = Assets.from_string("RUNE")

    provider
    |> Map.put(:id, "#{provider.asset}/#{provider.rune_address}")
    |> Map.put(:asset, asset)
    |> Map.update(:asset_address, nil, fn
      "" -> nil
      x -> x
    end)
    |> Map.update(:rune_address, nil, fn
      "" -> nil
      x -> x
    end)
    |> Map.update(:last_withdraw_height, nil, fn
      0 -> nil
      x -> x
    end)
    |> Map.update(:units, "0", &String.to_integer/1)
    |> Map.update(:pending_rune, "0", &String.to_integer/1)
    |> Map.update(:pending_asset, "0", &String.to_integer/1)
    |> Map.put(
      :value_usd,
      Price.value_usd(asset, provider.asset_redeem_value) +
        Price.value_usd(rune, provider.rune_redeem_value)
    )
    |> Map.update(:asset_redeem_value, "0", &String.to_integer/1)
    |> Map.update(:rune_redeem_value, "0", &String.to_integer/1)
    |> Map.update(:asset_deposit_value, "0", &String.to_integer/1)
    |> Map.update(:rune_deposit_value, "0", &String.to_integer/1)
    |> Map.update(:luvi_deposit_value, "0", &String.to_integer/1)
    |> Map.update(:luvi_redeem_value, "0", &String.to_integer/1)
    |> Map.update(:luvi_growth_pct, "0", &String.to_float/1)
  end

  def cast_pool(pool) do
    pool
    |> Map.put(:id, pool.asset)
    |> Map.put(:asset, Assets.from_string(pool.asset))
    |> Map.put(:lp_units, Map.get(pool, :LP_units))
    |> Map.update(:lp_units, "0", &String.to_integer/1)
    |> Map.update(:pending_inbound_asset, "0", &String.to_integer/1)
    |> Map.update(:pending_inbound_rune, "0", &String.to_integer/1)
    |> Map.update(:balance_asset, "0", &String.to_integer/1)
    |> Map.update(:balance_rune, "0", &String.to_integer/1)
    |> Map.update(
      :asset_tor_price,
      nil,
      &Decimal.div(Decimal.new(&1), Decimal.new(100_000_000))
    )
    |> Map.update(:pool_units, "0", &String.to_integer/1)
    |> Map.update(:derived_depth_bps, "0", &String.to_integer/1)
    |> Map.update(:savers_fill_bps, "0", &String.to_integer/1)
    |> Map.update(:savers_depth, "0", &String.to_integer/1)
    |> Map.update(:synth_supply_remaining, "0", &String.to_integer/1)
    |> Map.update(:synth_supply, "0", &String.to_integer/1)
    |> Map.update(:synth_units, "0", &String.to_integer/1)
    |> Map.update(:savers_units, "0", &String.to_integer/1)
    |> Map.update(:savers_capacity_remaining, "0", &String.to_integer/1)
  end

  defp cast_inbound_address(x) do
    x
    |> Map.update(:chain, nil, &String.to_existing_atom(String.downcase(&1)))
    |> Map.update(:gas_rate_units, nil, &maybe_string/1)
    |> Map.update(:pub_key, nil, &maybe_string/1)
    |> Map.update(:router, nil, &maybe_string/1)
    |> Map.update(:outbound_tx_size, "0", &String.to_integer/1)
    |> Map.update(:outbound_fee, "0", &String.to_integer/1)
    |> Map.update(:dust_threshold, "0", &String.to_integer/1)
    |> Map.update(:gas_rate, "0", &String.to_integer/1)
    |> Map.put(:id, x.chain)
  end

  defp cast_outbound_fee(x) do
    x
    |> Map.update(:outbound_fee, "0", &String.to_integer/1)
    |> Map.update(:fee_withheld_rune, nil, &maybe_to_integer/1)
    |> Map.update(:fee_spent_rune, nil, &maybe_to_integer/1)
    |> Map.update(:surplus_rune, nil, &maybe_to_integer/1)
    |> Map.update(:dynamic_multiplier_basis_points, nil, &maybe_to_integer/1)
  end

  defp cast_node_info(node_info) do
    node_info
    |> Map.update(:total_bond, "0", &String.to_integer/1)
    |> Map.update(:current_award, "0", &String.to_integer/1)
    |> Map.update(:bond_providers, nil, &cast_bond_providers/1)
  end

  defp cast_bond_providers(nil), do: nil

  defp cast_bond_providers(bond_providers) do
    bond_providers
    |> Map.update(:node_operator_fee, "0", &String.to_integer/1)
    |> Map.update(:providers, [], fn providers -> Enum.map(providers, &cast_bond_provider/1) end)
  end

  defp cast_bond_provider(provider) do
    provider
    |> Map.update(:bond, "0", &String.to_integer/1)
  end

  defp maybe_to_integer(""), do: nil
  defp maybe_to_integer(str), do: String.to_integer(str)
  defp maybe_string(""), do: nil
  defp maybe_string(str), do: str

  def get_dest_address(memo) do
    parts = String.split(memo, ":")

    if Enum.at(parts, 0) in ["SWAP", "="] do
      dest = Enum.at(parts, 2)
      {:ok, dest}
    else
      {:error, :invalid_memo}
    end
  end

  def tx_in(hash) do
    with {:ok,
          %QueryTxResponse{
            observed_tx: %{tx: tx} = observed_tx,
            finalised_height: finalised_height
          } = res} <-
           Rujira.Node.query(&Q.tx/3, %QueryTxRequest{tx_id: hash}, []),
         {:ok, block} <- block(finalised_height) do
      {:ok,
       res
       |> Map.put(:id, hash)
       |> Map.put(:observed_tx, %{observed_tx | tx: cast_tx(tx)})
       |> Map.put(:finalized_height, finalised_height)
       |> Map.put(
         :finalized_events,
         Enum.flat_map(
           block.txs,
           &finalized_events(&1, hash)
         )
       )}
    else
      {:error, _} ->
        {:ok, %{id: hash, observed_tx: nil, finalized_events: nil, finalized_height: nil}}
    end
  end

  def block(height) do
    with {:ok, %QueryBlockResponse{} = block} <-
           Rujira.Node.query(
             &Q.block/2,
             %QueryBlockRequest{height: to_string(height)}
           ) do
      Thorchain.parse_block(block)
    end
  end

  defp cast_tx(%Tx{
         id: id,
         chain: chain,
         from_address: from_address,
         to_address: to_address,
         coins: coins,
         gas: gas,
         memo: memo
       }) do
    %{
      id: id,
      chain: String.to_existing_atom(String.downcase(chain)),
      from_address: from_address,
      to_address: to_address,
      coins: Enum.map(coins, &cast_coin/1),
      gas: Enum.map(gas, &cast_coin/1),
      memo: memo
    }
  end

  defp cast_coin(%Coin{asset: asset, amount: amount}) do
    %{
      asset: %Asset{
        id: "#{asset.chain}.#{asset.symbol}",
        type: :layer_1,
        chain: asset.chain,
        symbol: asset.symbol,
        ticker: asset.ticker
      },
      amount: amount
    }
  end

  def oracle_price(symbol) do
    with {:ok, %{price: %{price: price}}} <-
           Rujira.Node.query(
             &Q.oracle_price/2,
             %QueryOraclePriceRequest{symbol: symbol}
           ) do
      {:ok, Decimal.new(price)}
    end
  end

  def tor_price("THOR.RUNE") do
    with {:ok, %{rune_price_in_tor: price}} <- network(),
         {:ok, price} <- Decimal.cast(price) do
      {:ok, Decimal.div(price, Decimal.new(100_000_000))}
    end
  end

  def tor_price(asset) do
    case pool(asset) do
      {:ok, %{asset_tor_price: price}} ->
        {:ok, price}

      _ ->
        {:ok, nil}
    end
  end

  # Holders query
  def get_holders(denom, limit \\ 100) do
    with {:ok, holders} <- get_holders_page(denom) do
      {:ok, holders |> Enum.sort_by(&Integer.parse(&1.balance.amount), :desc) |> Enum.take(limit)}
    end
  end

  defp get_holders_page(denom, key \\ nil)

  defp get_holders_page(denom, nil) do
    with {:ok, %{denom_owners: denom_owners, pagination: %{next_key: next_key}}} <-
           Rujira.Node.query(
             &denom_owners/3,
             %QueryDenomOwnersRequest{denom: denom},
             []
           ),
         {:ok, next} <- get_holders_page(denom, next_key) do
      {:ok, Enum.concat(denom_owners, next)}
    end
  end

  defp get_holders_page(_, "") do
    {:ok, []}
  end

  defp get_holders_page(denom, key) do
    with {:ok, %{denom_owners: denom_owners, pagination: %{next_key: next_key}}} <-
           Rujira.Node.query(
             &denom_owners/3,
             %QueryDenomOwnersRequest{denom: denom, pagination: %PageRequest{key: key}},
             []
           ),
         {:ok, next} <- get_holders_page(denom, next_key) do
      {:ok, Enum.concat(denom_owners, next)}
    end
  end

  defp finalized_events(%{result: %{events: events}}, hash) do
    Enum.filter(events, fn %{attributes: attributes} ->
      Enum.any?(attributes, &(elem(&1, 1) == hash))
    end)
  end

  def network() do
    Rujira.Node.query(&Q.network/3, %QueryNetworkRequest{}, [])
  end

  def node_info(address) do
    with {:ok, %QueryNodeResponse{} = node_info} <- Rujira.Node.query(&Q.node/2, %QueryNodeRequest{address: address}) do
      {:ok, cast_node_info(node_info)}
    end
  end
end
