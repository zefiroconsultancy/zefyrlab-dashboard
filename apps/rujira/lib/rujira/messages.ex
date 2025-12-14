defmodule Rujira.Messages do
  @moduledoc """
  Message helpers for creating standard Cosmos SDK and CosmWasm messages.

  This module provides a unified interface for creating properly encoded
  Google.Protobuf.Any messages using pattern matching on message structure.
  """

  alias Cosmwasm.Wasm.V1.MsgExecuteContract
  alias Cosmwasm.Wasm.V1.MsgInstantiateContract
  alias Cosmwasm.Wasm.V1.MsgInstantiateContract2
  alias Cosmwasm.Wasm.V1.MsgMigrateContract
  alias Cosmwasm.Wasm.V1.MsgUpdateAdmin
  alias Cosmos.Bank.V1beta1.MsgSend

  # Bank Messages
  def to_msg(%{from_address: from, to_address: to, amount: amount}) do
    msg = %MsgSend{
      from_address: from,
      to_address: to,
      amount: amount
    }

    to_any("/cosmos.bank.v1beta1.MsgSend", MsgSend.encode(msg))
  end

  # CosmWasm Messages
  def to_msg(%{sender: sender, contract: contract, msg: msg, funds: funds}) do
    msg = %MsgExecuteContract{
      sender: sender,
      contract: contract,
      msg: Jason.encode!(msg),
      funds: funds || []
    }

    to_any("/cosmwasm.wasm.v1.MsgExecuteContract", MsgExecuteContract.encode(msg))
  end

  def to_msg(%{
        sender: sender,
        admin: admin,
        code_id: code_id,
        msg: msg,
        funds: funds,
        label: label
      }) do
    msg = %MsgInstantiateContract{
      sender: sender,
      admin: admin,
      code_id: to_string(code_id),
      msg: Jason.encode!(msg),
      funds: funds || [],
      label: label || ""
    }

    to_any("/cosmwasm.wasm.v1.MsgInstantiateContract", MsgInstantiateContract.encode(msg))
  end

  def to_msg(%{sender: sender, contract: contract, code_id: code_id, msg: msg}) do
    msg = %MsgMigrateContract{
      sender: sender,
      contract: contract,
      code_id: to_string(code_id),
      msg: Jason.encode!(msg)
    }

    to_any("/cosmwasm.wasm.v1.MsgMigrateContract", MsgMigrateContract.encode(msg))
  end

  def to_msg(%{
        sender: sender,
        admin: admin,
        code_id: code_id,
        msg: msg,
        salt: salt,
        funds: funds,
        label: label
      }) do
    msg = %MsgInstantiateContract2{
      sender: sender,
      admin: admin,
      code_id: to_string(code_id),
      msg: Jason.encode!(msg),
      salt: salt,
      funds: funds || [],
      label: label || ""
    }

    to_any("/cosmwasm.wasm.v1.MsgInstantiateContract2", MsgInstantiateContract2.encode(msg))
  end

  def to_msg(%{sender: sender, new_admin: new_admin, contract: contract}) do
    msg = %MsgUpdateAdmin{
      sender: sender,
      new_admin: new_admin,
      contract: contract
    }

    to_any("/cosmwasm.wasm.v1.MsgUpdateAdmin", MsgUpdateAdmin.encode(msg))
  end

  def to_msg(_), do: {:error, :unknown_message}

  # Helper function to create Google.Protobuf.Any
  defp to_any(type, msg) do
    {:ok,
     %Google.Protobuf.Any{
       type_url: type,
       value: msg
     }}
  end
end
