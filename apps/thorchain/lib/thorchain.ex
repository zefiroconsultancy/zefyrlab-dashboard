defmodule Thorchain do
  @moduledoc """
  Main module for interacting with the Thorchain blockchain.

  This module provides functionality for querying and interacting with various aspects
  of the Thorchain network, including vaults, nodes, and liquidity providers.
  """

  alias Thorchain.Types.BlockEvent
  alias Thorchain.Types.BlockResponseHeader
  alias Thorchain.Types.BlockTxResult
  alias Thorchain.Types.QueryBlockResponse
  alias Thorchain.Types.QueryBlockTx

  def parse_block(%QueryBlockResponse{} = block) do
    {:ok,
     %{
       block
       | header: cast_block_header(block.header),
         begin_block_events: Enum.map(block.begin_block_events, &cast_block_event/1),
         end_block_events: Enum.map(block.end_block_events, &cast_block_event/1),
         txs: Enum.map(block.txs, &cast_block_tx/1)
     }}
  end

  defp cast_block_header(%BlockResponseHeader{chain_id: chain_id, height: height, time: time}) do
    {:ok, time, 0} = DateTime.from_iso8601(time)
    %{chain_id: chain_id, height: height, time: time}
  end

  defp cast_block_event(%BlockEvent{
         event_kv_pair: [
           %{key: "type", value: type}
           | attributes
         ]
       }) do
    # convert attributes to map to allow a more flexible access to attributes
    map_attr =
      Enum.reduce(attributes, %{}, fn %{key: key, value: value}, acc ->
        Map.put(acc, key, value)
      end)

    %{type: type, attributes: map_attr}
  end

  defp cast_block_tx(%QueryBlockTx{
         hash: hash,
         tx: tx,
         result: result
       }) do
    %{
      hash: hash,
      tx_data: tx,
      result: cast_block_tx_result(result)
    }
  end

  defp cast_block_tx_result(%BlockTxResult{
         code: code,
         data: data,
         log: log,
         info: info,
         gas_wanted: gas_wanted,
         gas_used: gas_used,
         events: events,
         codespace: codespace
       }) do
    %{
      code: code,
      data: data,
      log: log,
      info: info,
      gas_wanted: String.to_integer(gas_wanted),
      gas_used: String.to_integer(gas_used),
      events: Enum.map(events, &cast_block_event/1),
      codespace: codespace
    }
  end
end
